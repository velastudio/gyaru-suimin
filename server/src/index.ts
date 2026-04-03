import { Hono } from 'hono';
import { handle } from 'hono/vercel';

const app = new Hono();

app.get('/health', (c) => {
  return c.json({ status: 'ok' });
});

export { app };
export default handle(app);
