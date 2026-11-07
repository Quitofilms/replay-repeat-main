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
): Promise<{ id: string; downloadUrl: string }> {
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

  return { id: result.id, downloadUrl: result.webContentLink };
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
