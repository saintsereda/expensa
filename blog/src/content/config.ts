import { z, defineCollection } from 'astro:content';

const posts = defineCollection({
  type: 'content',
  schema: z.object({
    title: z.string(),
    titleTag: z.string().optional(),
    description: z.string(),
    date: z.date(),
    lang: z.string().optional(),
    videoId: z.string().optional(),
    videoTitle: z.string().optional(),
  }),
});

export const collections = { posts };
