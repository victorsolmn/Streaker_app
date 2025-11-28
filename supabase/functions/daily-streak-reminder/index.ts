import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Firebase V1 API endpoint
const FCM_V1_ENDPOINT = 'https://fcm.googleapis.com/v1/projects/streaker-342ad/messages:send'

// Service account credentials from environment
const FIREBASE_SERVICE_ACCOUNT = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')

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

// Send notification to FCM
async function sendNotification(
  accessToken: string,
  fcmToken: string,
  title: string,
  body: string,
  streakCount: number
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
              channel_id: 'streaks_channel',
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
            type: 'streak',
            screen: 'nutrition',
            streak_count: streakCount.toString(),
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

// Motivational messages based on streak length
function getMotivationalMessage(streakCount: number, userName: string): { title: string; body: string } {
  const name = userName || 'Champ'

  if (streakCount === 0) {
    const messages = [
      { title: "🌟 Start Fresh Today!", body: `Hey ${name}! Every journey starts with a single step. Log your meals today!` },
      { title: "💪 New Day, New Opportunity!", body: `${name}, today is perfect to begin your nutrition tracking journey!` },
      { title: "🎯 Ready to Begin?", body: `Hey ${name}! Your health goals are waiting. Start tracking today!` }
    ]
    return messages[Math.floor(Math.random() * messages.length)]
  }

  if (streakCount < 7) {
    const messages = [
      { title: `🔥 ${streakCount}-Day Streak!`, body: `Amazing ${name}! Keep it going - log your meals today!` },
      { title: `💪 ${streakCount} Days Strong!`, body: `You're building great habits, ${name}! Don't break the chain!` },
      { title: `⚡ ${streakCount}-Day Fire!`, body: `${name}, you're on a roll! Keep that streak alive today!` }
    ]
    return messages[Math.floor(Math.random() * messages.length)]
  }

  if (streakCount < 30) {
    const messages = [
      { title: `🔥 ${streakCount}-Day Streak!`, body: `Incredible ${name}! You're building serious momentum!` },
      { title: `🏆 ${streakCount} Days!`, body: `${name}, you're crushing it! Keep the streak alive!` },
      { title: `💎 ${streakCount}-Day Champion!`, body: `Wow ${name}! Your dedication is inspiring!` }
    ]
    return messages[Math.floor(Math.random() * messages.length)]
  }

  // 30+ days
  const messages = [
    { title: `🏆 ${streakCount}-Day Legend!`, body: `${name}, you're absolutely unstoppable! Keep going!` },
    { title: `👑 ${streakCount} Days!`, body: `${name}, you're a nutrition tracking master!` },
    { title: `🌟 ${streakCount}-Day Superstar!`, body: `Legendary commitment, ${name}! You're inspiring others!` }
  ]
  return messages[Math.floor(Math.random() * messages.length)]
}

serve(async (req) => {
  try {
    console.log('🔔 Daily streak reminder job started')

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Get today's date (start and end)
    const today = new Date()
    today.setHours(0, 0, 0, 0)
    const todayStr = today.toISOString().split('T')[0]

    // Get all users with active devices who haven't logged meals today
    // Join user_devices with profiles and check daily_metrics
    const { data: activeDevices, error: devicesError } = await supabase
      .from('user_devices')
      .select(`
        fcm_token,
        user_id,
        platform
      `)
      .eq('is_active', true)

    if (devicesError) {
      throw new Error(`Failed to fetch devices: ${devicesError.message}`)
    }

    if (!activeDevices || activeDevices.length === 0) {
      console.log('No active devices found')
      return new Response(JSON.stringify({
        success: true,
        message: 'No active devices to notify'
      }), {
        headers: { 'Content-Type': 'application/json' }
      })
    }

    console.log(`Found ${activeDevices.length} active devices`)

    // Get unique user IDs
    const userIds = [...new Set(activeDevices.map(d => d.user_id))]

    // Get user profiles for names
    const { data: profiles } = await supabase
      .from('profiles')
      .select('id, name')
      .in('id', userIds)

    const profileMap = new Map(profiles?.map(p => [p.id, p.name]) || [])

    // Check which users have already logged today
    const { data: todayLogs } = await supabase
      .from('daily_metrics')
      .select('user_id')
      .gte('date', todayStr)
      .lt('date', new Date(today.getTime() + 86400000).toISOString().split('T')[0])

    const usersLoggedToday = new Set(todayLogs?.map(l => l.user_id) || [])

    // Get current streaks for users
    const { data: streakData } = await supabase
      .from('streaks')
      .select('user_id, current_streak')
      .in('user_id', userIds)

    const streakMap = new Map(streakData?.map(s => [s.user_id, s.current_streak]) || [])

    // Get access token for FCM
    const accessToken = await getAccessToken()

    let successCount = 0
    let skipCount = 0
    let failCount = 0

    // Send reminders to users who haven't logged today
    for (const device of activeDevices) {
      // Skip users who already logged today
      if (usersLoggedToday.has(device.user_id)) {
        skipCount++
        continue
      }

      const userName = profileMap.get(device.user_id) || ''
      const streakCount = streakMap.get(device.user_id) || 0
      const { title, body } = getMotivationalMessage(streakCount, userName)

      const success = await sendNotification(
        accessToken,
        device.fcm_token,
        title,
        body,
        streakCount
      )

      if (success) {
        successCount++
      } else {
        failCount++
      }
    }

    console.log(`✅ Reminders sent: ${successCount} success, ${skipCount} skipped (already logged), ${failCount} failed`)

    return new Response(JSON.stringify({
      success: true,
      totalDevices: activeDevices.length,
      successCount,
      skipCount,
      failCount,
      timestamp: new Date().toISOString()
    }), {
      headers: { 'Content-Type': 'application/json' }
    })

  } catch (error) {
    console.error('❌ Daily reminder error:', error)
    return new Response(JSON.stringify({
      error: error.message
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    })
  }
})
