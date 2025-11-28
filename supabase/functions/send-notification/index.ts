import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Firebase V1 API endpoint
const FCM_V1_ENDPOINT = 'https://fcm.googleapis.com/v1/projects/streaker-342ad/messages:send'

// Service account credentials from environment
const FIREBASE_SERVICE_ACCOUNT = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')

interface NotificationRequest {
  user_ids?: string[]
  topic?: string
  title: string
  body: string
  type?: 'streak' | 'achievement' | 'goal' | 'general'
  screen?: string
  data?: Record<string, string>
}

interface FCMMessage {
  message: {
    token?: string
    topic?: string
    notification: {
      title: string
      body: string
    }
    android?: {
      priority: string
      notification: {
        channel_id: string
        icon: string
        color: string
      }
    }
    apns?: {
      payload: {
        aps: {
          alert: {
            title: string
            body: string
          }
          sound: string
          badge: number
        }
      }
    }
    data?: Record<string, string>
  }
}

// Get OAuth2 access token using service account
async function getAccessToken(): Promise<string> {
  if (!FIREBASE_SERVICE_ACCOUNT) {
    throw new Error('FIREBASE_SERVICE_ACCOUNT environment variable not set')
  }

  const serviceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT)

  // Create JWT header
  const header = {
    alg: 'RS256',
    typ: 'JWT'
  }

  // Create JWT claims
  const now = Math.floor(Date.now() / 1000)
  const claims = {
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
    scope: 'https://www.googleapis.com/auth/firebase.messaging'
  }

  // Base64URL encode
  const base64UrlEncode = (obj: object) => {
    const json = JSON.stringify(obj)
    const base64 = btoa(json)
    return base64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '')
  }

  const headerEncoded = base64UrlEncode(header)
  const claimsEncoded = base64UrlEncode(claims)
  const signatureInput = `${headerEncoded}.${claimsEncoded}`

  // Import private key and sign
  const privateKeyPem = serviceAccount.private_key
  const pemContents = privateKeyPem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\n/g, '')

  const binaryKey = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0))

  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    binaryKey,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign']
  )

  const signatureBuffer = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    new TextEncoder().encode(signatureInput)
  )

  const signature = btoa(String.fromCharCode(...new Uint8Array(signatureBuffer)))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '')

  const jwt = `${signatureInput}.${signature}`

  // Exchange JWT for access token
  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`
  })

  const tokenData = await tokenResponse.json()

  if (!tokenData.access_token) {
    console.error('Token response:', tokenData)
    throw new Error('Failed to get access token')
  }

  return tokenData.access_token
}

// Get notification channel based on type
function getNotificationChannel(type: string): string {
  switch (type) {
    case 'streak':
      return 'streaks_channel'
    case 'achievement':
      return 'achievements_channel'
    case 'goal':
      return 'goals_channel'
    default:
      return 'general_channel'
  }
}

// Build FCM message payload
function buildMessage(
  token: string | null,
  topic: string | null,
  title: string,
  body: string,
  type: string,
  screen?: string,
  customData?: Record<string, string>
): FCMMessage {
  const channelId = getNotificationChannel(type)

  const message: FCMMessage = {
    message: {
      notification: {
        title,
        body
      },
      android: {
        priority: 'high',
        notification: {
          channel_id: channelId,
          icon: 'ic_launcher',
          color: '#FF6B35'
        }
      },
      apns: {
        payload: {
          aps: {
            alert: { title, body },
            sound: 'default',
            badge: 1
          }
        }
      },
      data: {
        type,
        screen: screen || 'home',
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        ...customData
      }
    }
  }

  if (token) {
    message.message.token = token
  } else if (topic) {
    message.message.topic = topic
  }

  return message
}

// Send notification to FCM
async function sendToFCM(
  accessToken: string,
  message: FCMMessage
): Promise<{ success: boolean; error?: string }> {
  try {
    const response = await fetch(FCM_V1_ENDPOINT, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(message)
    })

    const result = await response.json()

    if (!response.ok) {
      console.error('FCM Error:', result)
      return { success: false, error: result.error?.message || 'Unknown error' }
    }

    return { success: true }
  } catch (error) {
    console.error('Send error:', error)
    return { success: false, error: error.message }
  }
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
      }
    })
  }

  try {
    const { user_ids, topic, title, body, type = 'general', screen, data } = await req.json() as NotificationRequest

    if (!title || !body) {
      return new Response(
        JSON.stringify({ error: 'Title and body are required' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Get access token
    const accessToken = await getAccessToken()

    // If sending to topic (broadcast)
    if (topic) {
      const message = buildMessage(null, topic, title, body, type, screen, data)
      const result = await sendToFCM(accessToken, message)

      return new Response(
        JSON.stringify({
          success: result.success,
          topic,
          error: result.error
        }),
        { headers: { 'Content-Type': 'application/json' } }
      )
    }

    // If sending to specific users
    if (!user_ids || user_ids.length === 0) {
      return new Response(
        JSON.stringify({ error: 'Either user_ids or topic is required' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Get Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Get FCM tokens for the specified users
    const { data: devices, error: dbError } = await supabase
      .from('user_devices')
      .select('fcm_token, user_id')
      .in('user_id', user_ids)
      .eq('is_active', true)

    if (dbError) {
      console.error('Database error:', dbError)
      return new Response(
        JSON.stringify({ error: 'Failed to fetch device tokens' }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      )
    }

    if (!devices || devices.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          message: 'No active devices found for specified users',
          successCount: 0,
          failureCount: 0
        }),
        { headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Send to each device
    const results = []
    let successCount = 0
    let failureCount = 0
    const invalidTokens: string[] = []

    for (const device of devices) {
      const message = buildMessage(device.fcm_token, null, title, body, type, screen, data)
      const result = await sendToFCM(accessToken, message)

      results.push({
        user_id: device.user_id,
        success: result.success,
        error: result.error
      })

      if (result.success) {
        successCount++
      } else {
        failureCount++
        // Check if token is invalid
        if (result.error?.includes('not found') ||
            result.error?.includes('invalid') ||
            result.error?.includes('unregistered')) {
          invalidTokens.push(device.fcm_token)
        }
      }
    }

    // Clean up invalid tokens
    if (invalidTokens.length > 0) {
      await supabase
        .from('user_devices')
        .update({ is_active: false })
        .in('fcm_token', invalidTokens)

      console.log(`Deactivated ${invalidTokens.length} invalid tokens`)
    }

    return new Response(
      JSON.stringify({
        success: true,
        successCount,
        failureCount,
        totalTokens: devices.length,
        results
      }),
      { headers: { 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Function error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})

/* Example usage:

POST https://xzwvckziavhzmghizyqx.supabase.co/functions/v1/send-notification
Headers:
  Authorization: Bearer YOUR_SUPABASE_ANON_KEY
  Content-Type: application/json

Body (send to specific users):
{
  "user_ids": ["user-uuid-1", "user-uuid-2"],
  "title": "🔥 Keep your streak alive!",
  "body": "You haven't logged your meals today. Don't break your 7-day streak!",
  "type": "streak",
  "screen": "nutrition"
}

Body (send to topic/broadcast):
{
  "topic": "daily_reminders",
  "title": "💪 Time to work out!",
  "body": "Your daily workout reminder is here!",
  "type": "general",
  "screen": "home"
}

*/
