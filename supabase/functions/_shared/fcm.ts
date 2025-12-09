
// Helper function to convert string to ArrayBuffer
function str2ab(str: string): ArrayBuffer {
  const buf = new ArrayBuffer(str.length);
  const bufView = new Uint8Array(buf);
  for (let i = 0, strLen = str.length; i < strLen; i++) {
    bufView[i] = str.charCodeAt(i);
  }
  return buf;
}

// Helper function to Base64Url-encode a buffer
function base64url(buf: ArrayBuffer): string {
  // Deno's standard `btoa` function is used here.
  // @ts-ignore
  return btoa(String.fromCharCode(...new Uint8Array(buf)))
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');
}

export async function getAuthToken() {
    const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
    if (!serviceAccountJson) {
        throw new Error("Server configuration error: FIREBASE_SERVICE_ACCOUNT_JSON environment variable not set.");
    }

    let serviceAccount;
    try {
        serviceAccount = JSON.parse(serviceAccountJson);
    } catch (e) {
        throw new Error("Server configuration error: Invalid FIREBASE_SERVICE_ACCOUNT_JSON.");
    }
    
    // 1. Import the private key using the standard Web Crypto API
    const privateKeyPEM = serviceAccount.private_key
        .replace("-----BEGIN PRIVATE KEY-----", "")
        .replace("-----END PRIVATE KEY-----", "")
        .replace(/\n/g, "");

    // Deno's standard `atob` function is used here.
    // @ts-ignore
    const privateKeyDer = str2ab(atob(privateKeyPEM));

    const cryptoKey = await crypto.subtle.importKey(
        "pkcs8",
        privateKeyDer,
        { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
        true,
        ["sign"]
    );

    // 2. Create the JWT header and payload
    const header = { alg: "RS256", typ: "JWT" };
    const iat = Math.floor(Date.now() / 1000);
    const exp = iat + 3600;

    const payload = {
        iss: serviceAccount.client_email,
        scope: "https://www.googleapis.com/auth/firebase.messaging",
        aud: "https://oauth2.googleapis.com/token",
        exp: exp,
        iat: iat,
    };
    
    // 3. Sign the JWT using the standard Web Crypto API
    const signingInput = `${base64url(str2ab(JSON.stringify(header)))}.${base64url(str2ab(JSON.stringify(payload)))}`;
    const signature = await crypto.subtle.sign(
        "RSASSA-PKCS1-v1_5",
        cryptoKey,
        str2ab(signingInput)
    );
    
    const jwt = `${signingInput}.${base64url(signature)}`;

    // 4. Request the access token from Google
    const res = await fetch("https://oauth2.googleapis.com/token", {
        method: "POST",
        headers: {
            "Content-Type": "application/x-www-form-urlencoded",
        },
        body: new URLSearchParams({
            grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
            assertion: jwt,
        }),
    });

    if (!res.ok) {
        const errorBody = await res.text();
        throw new Error(`Failed to get Google access token: ${res.status} ${errorBody}`);
    }

    const data = await res.json();
    return data.access_token;
}
