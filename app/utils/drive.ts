/** Google Drive upload and link sharing for local media. */
const CLIENT_ID = import.meta.env.VITE_GOOGLE_CLIENT_ID;
const DRIVE_FOLDER_ID = '1EU8JNBXAVdUC5G0FenwMF2EBy-LRgoFv';
const DRIVE_SCOPE = 'https://www.googleapis.com/auth/drive';

type TokenResponse = { access_token?: string; error?: string; error_description?: string };
type DriveIdentity = {
  accounts: {
    oauth2: {
      initTokenClient(options: {
        client_id: string;
        scope: string;
        callback: (response: TokenResponse) => void;
        error_callback?: (error: { message?: string }) => void;
      }): { requestAccessToken(options?: { prompt?: string }): void };
    };
  };
};

declare global {
  interface Window {
    google?: DriveIdentity;
  }
}

let identityReady: Promise<void> | undefined;

function loadIdentity(): Promise<void> {
  if (window.google?.accounts?.oauth2) return Promise.resolve();
  identityReady ??= new Promise((resolve, reject) => {
    const script = document.createElement('script');
    script.src = 'https://accounts.google.com/gsi/client';
    script.async = true;
    script.defer = true;
    script.onload = () => window.google?.accounts?.oauth2 ? resolve() : reject(new Error('Google sign-in did not initialize.'));
    script.onerror = () => {
      identityReady = undefined;
      reject(new Error('Google sign-in could not load. Check your network connection.'));
    };
    document.head.append(script);
  });
  return identityReady;
}

export function prepareDrive(): void {
  if (CLIENT_ID) void loadIdentity().catch(() => {});
}

function accessToken(): Promise<string> {
  if (!CLIENT_ID) {
    return Promise.reject(new Error('Drive uploads need a Google OAuth client ID. Set VITE_GOOGLE_CLIENT_ID as described in the README.'));
  }
  return new Promise((resolve, reject) => {
    void loadIdentity().then(() => {
      const client = window.google!.accounts.oauth2.initTokenClient({
        client_id: CLIENT_ID,
        scope: DRIVE_SCOPE,
        callback: (response) => {
          if (response.error || !response.access_token) {
            reject(new Error(response.error_description || response.error || 'Google did not grant Drive access.'));
          } else {
            resolve(response.access_token);
          }
        },
        error_callback: (error) => reject(new Error(error.message || 'Google sign-in was closed.')),
      });
      client.requestAccessToken({ prompt: '' });
    }, reject);
  });
}

async function apiError(response: Response): Promise<Error> {
  let detail = '';
  try {
    const body = await response.json() as { error?: { message?: string } };
    detail = body.error?.message || '';
  } catch { /* Use the HTTP status when Drive returned no JSON. */ }
  return new Error(detail || `Google Drive returned ${response.status} ${response.statusText}.`);
}

/** Uploads a local video and grants read access to anyone with its link. */
export async function uploadToDrive(
  file: File,
  title: string,
  note: string,
): Promise<{ id: string; downloadUrl: string; token: string }> {
  const token = await accessToken();
  const extension = file.name.includes('.') ? `.${file.name.split('.').pop()}` : '';
  const name = `${title.trim() || file.name.replace(/\.[^.]+$/, '')}${extension}`;
  const mimeType = file.type || 'application/octet-stream';
  const start = await fetch('https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable&fields=id,webContentLink', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json; charset=UTF-8',
      'X-Upload-Content-Type': mimeType,
      'X-Upload-Content-Length': String(file.size),
    },
    body: JSON.stringify({
      name,
      mimeType,
      description: note.trim(),
      parents: [DRIVE_FOLDER_ID],
    }),
  });
  if (!start.ok) throw await apiError(start);
  const session = start.headers.get('Location');
  if (!session) throw new Error('Google Drive did not return an upload session.');

  const uploaded = await fetch(session, {
    method: 'PUT',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': mimeType },
    body: file,
  });
  if (!uploaded.ok) throw await apiError(uploaded);
  const result = await uploaded.json() as { id?: string; webContentLink?: string };
  if (!result.id || !result.webContentLink) {
    throw new Error("Google Drive uploaded the video but did not return its browser download link.");
  }

  const permission = await fetch(`https://www.googleapis.com/drive/v3/files/${encodeURIComponent(result.id)}/permissions`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ type: 'anyone', role: 'reader' }),
  });
  if (!permission.ok) {
    const error = await apiError(permission);
    try {
      await fetch(`https://www.googleapis.com/drive/v3/files/${encodeURIComponent(result.id)}`, {
        method: 'DELETE', headers: { Authorization: `Bearer ${token}` },
      });
    } catch { /* A private orphan can be removed from Drive manually if cleanup fails. */ }
    throw new Error(`The upload finished, but Drive could not enable link sharing: ${error.message}`);
  }

  return { id: result.id, downloadUrl: result.webContentLink, token };
}

export function isDriveDownloadUrl(value: string | undefined): value is string {
  if (!value) return false;
  try {
    const url = new URL(value);
    return url.protocol === "https:" && ["drive.google.com", "drive.usercontent.google.com"].includes(url.hostname);
  } catch {
    return false;
  }
}

export function driveViewUrl(id: string): string {
  return `https://drive.google.com/file/d/${encodeURIComponent(id)}/view`;
}

export function driveMediaUrl(id: string): string {
  return `https://drive.google.com/uc?export=download&id=${encodeURIComponent(id)}`;
}

export interface SharedSavedReplay {
  id: string;
  title: string;
  note: string;
  url: string;
  savedAt: string;
}

const SAVED_LIST_NAME = 'replay-repeat-saved.json';

async function savedListFileId(token: string): Promise<string | undefined> {
  const query = new URLSearchParams({
    q: `'${DRIVE_FOLDER_ID}' in parents and name = '${SAVED_LIST_NAME}' and trashed = false`,
    fields: 'files(id)',
    pageSize: '1',
    spaces: 'drive',
  });
  const response = await fetch(`https://www.googleapis.com/drive/v3/files?${query}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!response.ok) throw await apiError(response);
  const result = await response.json() as { files?: Array<{ id?: string }> };
  return result.files?.[0]?.id;
}

export async function saveSharedSavedReplays(
  items: SharedSavedReplay[],
  existingToken?: string,
): Promise<SharedSavedReplay[]> {
  const token = existingToken ?? await accessToken();
  const id = await savedListFileId(token);
  let previous: SharedSavedReplay[] = [];

  if (id) {
    const response = await fetch(`https://www.googleapis.com/drive/v3/files/${encodeURIComponent(id)}?alt=media`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!response.ok) throw await apiError(response);
    const content = await response.json() as unknown;
    if (!Array.isArray(content)) throw new Error('The shared saved list in Drive is not a valid list.');
    previous = content as SharedSavedReplay[];
  }

  const merged = new Map<string, SharedSavedReplay>();
  for (const item of previous) merged.set(item.id, item);
  for (const item of items) merged.set(item.id, item);
  const saved = [...merged.values()].sort((a, b) => b.savedAt.localeCompare(a.savedAt));
  const media = new Blob([JSON.stringify(saved, null, 2)], { type: 'application/json' });

  if (id) {
    const response = await fetch(`https://www.googleapis.com/upload/drive/v3/files/${encodeURIComponent(id)}?uploadType=media&fields=id`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: media,
    });
    if (!response.ok) throw await apiError(response);
  } else {
    const start = await fetch('https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable&fields=id', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json; charset=UTF-8',
        'X-Upload-Content-Type': 'application/json',
        'X-Upload-Content-Length': String(media.size),
      },
      body: JSON.stringify({ name: SAVED_LIST_NAME, mimeType: 'application/json', parents: [DRIVE_FOLDER_ID] }),
    });
    if (!start.ok) throw await apiError(start);
    const session = start.headers.get('Location');
    if (!session) throw new Error('Google Drive did not return an upload session for the saved list.');
    const uploaded = await fetch(session, {
      method: 'PUT',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: media,
    });
    if (!uploaded.ok) throw await apiError(uploaded);
  }

  return saved;
}
export async function removeSharedSavedReplay(idToRemove: string): Promise<SharedSavedReplay[]> {
  const token = await accessToken();
  const id = await savedListFileId(token);
  if (!id) return [];

  const response = await fetch(`https://www.googleapis.com/drive/v3/files/${encodeURIComponent(id)}?alt=media`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!response.ok) throw await apiError(response);
  const content = await response.json() as unknown;
  if (!Array.isArray(content)) throw new Error('The shared saved list in Drive is not a valid list.');
  const saved = (content as SharedSavedReplay[]).filter((item) => item.id !== idToRemove);
  const media = new Blob([JSON.stringify(saved, null, 2)], { type: 'application/json' });
  const update = await fetch(`https://www.googleapis.com/upload/drive/v3/files/${encodeURIComponent(id)}?uploadType=media&fields=id`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: media,
  });
  if (!update.ok) throw await apiError(update);
  return saved;
}
