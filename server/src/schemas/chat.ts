import { z } from 'zod';

export const chatRequestSchema = z.object({
  sessionId: z.string(),
  message: z.string(),
});

export type ChatRequest = z.infer<typeof chatRequestSchema>;
