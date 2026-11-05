import express, { Request, Response } from 'express';
import cors from 'cors';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const isProd = process.env.NODE_ENV === 'production';
const PORT = 3000;

async function startServer() {
  const app = express();

  app.use(cors());
  app.use(express.json());

  // Subsonic API proxy to prevent browser CORS issues with self-hosted Navidrome instances
  app.post('/api/subsonic/proxy', async (req: Request, res: Response) => {
    try {
      const { serverUrl, user, pass, endpoint, params } = req.body;

      if (!serverUrl || !user || !pass || !endpoint) {
        return res.status(400).json({
          'subsonic-response': {
            status: 'failed',
            error: { code: 10, message: 'Missing required connection parameters' },
          },
        });
      }

      const cleanUrl = serverUrl.replace(/\/+$/, '');
      const query = new URLSearchParams();
      query.set('u', user);
      query.set('p', pass);
      query.set('v', '1.12.0');
      query.set('c', 'koreader-navidrome');
      query.set('f', 'json');

      if (params && typeof params === 'object') {
        for (const [key, value] of Object.entries(params)) {
          if (value !== undefined && value !== null) {
            query.set(key, String(value));
          }
        }
      }

      const targetUrl = `${cleanUrl}/rest/${endpoint}?${query.toString()}`;
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 12000);

      const upstream = await fetch(targetUrl, {
        method: 'GET',
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'koreader-navidrome/1.0',
        },
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      if (!upstream.ok) {
        return res.status(upstream.status).json({
          'subsonic-response': {
            status: 'failed',
            error: {
              code: upstream.status,
              message: `Navidrome server responded with HTTP ${upstream.status} (${upstream.statusText})`,
            },
          },
        });
      }

      const text = await upstream.text();
      try {
        const json = JSON.parse(text);
        return res.json(json);
      } catch {
        return res.status(502).json({
          'subsonic-response': {
            status: 'failed',
            error: { code: 50, message: 'Invalid JSON response from Navidrome server' },
          },
        });
      }
    } catch (err: unknown) {
      const error = err as Error;
      const isTimeout = error.name === 'AbortError';
      return res.status(isTimeout ? 504 : 500).json({
        'subsonic-response': {
          status: 'failed',
          error: {
            code: isTimeout ? 408 : 0,
            message: isTimeout
              ? 'Connection timed out connecting to Navidrome server'
              : `Connection error: ${error.message || 'Failed to reach server'}`,
          },
        },
      });
    }
  });

  // Cover art proxy for authenticated images
  app.get('/api/subsonic/cover', async (req: Request, res: Response) => {
    try {
      const { serverUrl, user, pass, id, size } = req.query;

      if (!serverUrl || !user || !pass || !id) {
        return res.status(400).send('Missing cover art parameters');
      }

      const cleanUrl = String(serverUrl).replace(/\/+$/, '');
      const query = new URLSearchParams();
      query.set('u', String(user));
      query.set('p', String(pass));
      query.set('v', '1.12.0');
      query.set('c', 'koreader-navidrome');
      query.set('id', String(id));
      if (size) query.set('size', String(size));

      const targetUrl = `${cleanUrl}/rest/getCoverArt.view?${query.toString()}`;
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 12000);

      const upstream = await fetch(targetUrl, {
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      if (!upstream.ok) {
        return res.status(upstream.status).send('Cover not found');
      }

      const contentType = upstream.headers.get('content-type') || 'image/jpeg';
      res.setHeader('Content-Type', contentType);
      res.setHeader('Cache-Control', 'public, max-age=86400');

      const arrayBuffer = await upstream.arrayBuffer();
      res.send(Buffer.from(arrayBuffer));
    } catch {
      res.status(502).send('Error retrieving cover art');
    }
  });

  // Health check
  app.get('/api/health', (_req, res) => {
    res.json({ ok: true, app: 'navidrome-jukebox' });
  });

  // Vite integration
  if (!isProd) {
    const { createServer: createViteServer } = await import('vite');
    const vite = await createViteServer({
      server: { middlewareMode: true, hmr: false },
      appType: 'spa',
    });
    app.use(vite.middlewares);
  } else {
    app.use(express.static(path.resolve(__dirname, 'dist')));
    app.get('*', (_req, res) => {
      res.sendFile(path.resolve(__dirname, 'dist', 'index.html'));
    });
  }

  app.listen(PORT, '0.0.0.0', () => {
    console.log(`[Navidrome Jukebox] Server listening on http://0.0.0.0:${PORT}`);
  });
}

startServer();
