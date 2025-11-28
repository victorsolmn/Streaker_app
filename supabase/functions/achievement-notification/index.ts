import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Firebase V1 API endpoint
const FCM_V1_ENDPOINT = 'https://fcm.googleapis.com/v1/projects/streaker-342ad/messages:send'

// Service account credentials from environment
const FIREBASE_SERVICE_ACCOUNT = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')

// Achievement milestones
const STREAK_MILESTONES = [3, 7, 14, 21, 30, 60, 90, 100, 180, 365]

interface AchievementRequest {
  user_id: string
  streak_count: number
  achievement_type?: 'streak' | 'goal' | 'first_log'
}

// Get OAuth2 access token using service account
async function getAccessToken(): Promise<string> {
  if (!FIREBASE_SERVICE_ACCOUNT) {
    throw new Error('FIREBASE_SERVICE_ACCOUNT environment variable not set')
  }

  const serviceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT)

  const header = { alg: 'RS256', typ: 'JWT' }
  const now = Math.floor(Date.now() / 1000)
  const claims = {
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
    scope: 'https://www.googleapis.com/auth/firebase.messaging'
  }

  const base64UrlEncode = (obj: object) => {
    const json = JSON.stringify(obj)
    const base64 = btoa(json)
    return base64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '')
  }

  const headerEncoded = base64UrlEncode(header)
  const claimsEncoded = base64UrlEncode(claims)
  const signatureInput = `${headerEncoded}.${claimsEncoded}`

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

  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`
  })

  const tokenData = await tokenResponse.json()

  if (!tokenData.access_token) {
    throw new Error('Failed to get access token')
  }

  return tokenData.access_token
}

// Get achievement message based on milestone
function getAchievementMessage(streakCount: number, userName: string): { title: string; body: string } | null {
  const name = userName || 'Champion'

  // Check if this is a milestone
  if (!STREAK_MILESTONES.includes(streakCount)) {
    return null
  }

  switch (streakCount) {
    case 3:
      return {
        title: "🎉 3-Day Streak Unlocked!",
        body: `Amazing start ${name}! You've built momentum. Keep it going!`
      }
    case 7:
      return {
        title: "🔥 1-Week Champion!",
        body: `Incredible ${name}! A full week of consistency. You're building real habits!`
      }
    case 14:
      return {
        title: "⭐ 2-Week Warrior!",
        body: `${name}, two weeks strong! Your dedication is paying off!`
      }
    case 21:
      return {
        title: "🏆 21-Day Legend!",
        body: `${name}, they say it takes 21 days to form a habit. You did it!`
      }
    case 30:
      return {
        title: "👑 30-Day Royalty!",
        body: `A full month ${name}! You're officially a nutrition tracking master!`
      }
    case 60:
      return {
        title: "💎 60-Day Diamond!",
        body: `Two months of excellence, ${name}! You're unstoppable!`
      }
    case 90:
      return {
        title: "🌟 90-Day Superstar!",
        body: `Three months ${name}! Your commitment is truly inspiring!`
      }
    case 100:
      return {
        title: "💯 100-Day Century!",
        body: `WOW ${name}! 100 days! You're in the elite club now!`
      }
    case 180:
      return {
        title: "🚀 180-Day Rocket!",
        body: `Half a year ${name}! Your transformation is remarkable!`
      }
    case 365:
      return {
        title: "🏅 365-Day LEGEND!",
        body: `ONE FULL YEAR ${name}! You are absolutely LEGENDARY!`
      }
    default:
      return null
  }
}

// Get first log message
function getFirstLogMessage(userName: string): { title: string; body: string } {
  const name = userName || 'there'
  return {
    title: "🎊 First Meal Logged!",
    body: `Welcome ${name}! You've taken the first step on your health journey!`
  }
}

// Get goal achieved message
function getGoalAchievedMessage(userName: string): { title: string; body: string } {
  const name = userName || 'Champion'
  const messages = [
    { title: "🎯 Daily Goal Crushed!", body: `Amazing ${name}! You hit all your nutrition targets today!` },
    { title: "✅ Goals Complete!", body: `${name}, you've achieved all your daily goals! Keep it up!` },
    { title: "💪 Perfect Day!", body: `${name}, every goal met! You're on fire!` }
  ]
  return messages[Math.floor(Math.random() * messages.length)]
}

// Send notification to FCM
async function sendNotification(
  accessToken: string,
  fcmToken: string,
  title: string,
  body: string,
  achievementType: string
): Promise<boolean> {
  try {
    const response = await fetch(FCM_V1_ENDPOINT, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        message: {
          token: fcmToken,
          notification: { title, body },
          android: {
            priority: 'high',
            notification: {
              channel_id: 'achievements_channel',
              icon: 'ic_launcher',
              color: '#FFD700' // Gold color for achievements
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
            type: 'achievement',
            achievement_type: achievementType,
            screen: 'achievements',
            click_action: 'FLUTTER_NOTIFICATION_CLICK'
          }
        }
      })
    })

    return response.ok
  } catch (error) {
    console.error('Send error:', error)
    return false
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
    const { user_id, streak_count, achievement_type = 'streak' } = await req.json() as AchievementRequest

    if (!user_id) {
      return new Response(JSON.stringify({ error: 'user_id is required' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      })
    }

    console.log(`🏆 Achievement check for user ${user_id}, streak: ${streak_count}, type: ${achievement_type}`)

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Get user profile
    const { data: profile } = await supabase
      .from('profiles')
      .select('name')
      .eq('id', user_id)
      .single()

    const userName = profile?.name || ''

    // Get message based on achievement type
    let message: { title: string; body: string } | null = null

    switch (achievement_type) {
      case 'streak':
        message = getAchievementMessage(streak_count, userName)
        break
      case 'first_log':
        message = getFirstLogMessage(userName)
        break
      case 'goal':
        message = getGoalAchievedMessage(userName)
        break
    }

    if (!message) {
      console.log(`No achievement notification for streak ${streak_count}`)
      return new Response(JSON.stringify({
        success: true,
        notified: false,
        reason: 'Not a milestone'
      }), {
        headers: { 'Content-Type': 'application/json' }
      })
    }

    // Get user's active devices
    const { data: devices, error: devicesError } = await supabase
      .from('user_devices')
      .select('fcm_token')
      .eq('user_id', user_id)
      .eq('is_active', true)

    if (devicesError || !devices || devices.length === 0) {
      console.log('No active devices for user')
      return new Response(JSON.stringify({
        success: true,
        notified: false,
        reason: 'No active devices'
      }), {
        headers: { 'Content-Type': 'application/json' }
      })
    }

    // Get access token
    const accessToken = await getAccessToken()

    // Send to all devices
    let successCount = 0
    for (const device of devices) {
      const success = await sendNotification(
        accessToken,
        device.fcm_token,
        message.title,
        message.body,
        achievement_type
      )
      if (success) successCount++
    }

    console.log(`✅ Achievement notification sent to ${successCount}/${devices.length} devices`)

    return new Response(JSON.stringify({
      success: true,
      notified: true,
      achievement: message.title,
      devicesNotified: successCount
    }), {
      headers: { 'Content-Type': 'application/json' }
    })

  } catch (error) {
    console.error('❌ Achievement notification error:', error)
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    })
  }
})
