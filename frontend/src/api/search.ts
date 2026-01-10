import apiClient from './client';

export interface SearchItem {
  title?: string;
  name?: string;
  filename?: string;
  url?: string;
}

export interface SearchResponse {
  q: string;
  page: number;
  items: SearchItem[];
  provider: string;
  enabled: boolean;
  warning?: string;
}

export async function search(q: string, page: number = 1): Promise<SearchResponse> {
  const response = await apiClient.get<SearchResponse>('/api/search', {
    params: { q, page },
  });
  return response.data;
}
