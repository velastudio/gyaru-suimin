import { z } from 'zod';

export const chatRequestSchema = z.object({
  sessionId: z.string().min(1, 'sessionId is required'),
  message: z
    .string()
    .refine((value) => value.trim().length > 0, 'message is required')
    .refine(
      (value) => Array.from(value).length <= 1000,
      'message must be at most 1000 characters',
    ),
});

export type ChatRequest = z.infer<typeof chatRequestSchema>;

export function validateChatRequest(input: unknown): ChatRequest {
  return chatRequestSchema.parse(input);
}
