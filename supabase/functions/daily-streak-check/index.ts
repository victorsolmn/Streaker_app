import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabaseUrl = 'https://xzwvckziavhzmghizyqx.supabase.co'
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Check if this is a scheduled call or manual trigger
    const { isScheduled } = await req.json().catch(() => ({ isScheduled: false }))

    console.log(`Daily streak check started at ${new Date().toISOString()}`)
    console.log(`Triggered by: ${isScheduled ? 'Schedule' : 'Manual'}`)

    // Call the database function to check all user streaks
    const { data, error } = await supabase.rpc('daily_streak_check_endpoint')

    if (error) {
      console.error('Error running daily streak check:', error)
      throw error
    }

    console.log('Daily streak check completed successfully:', data)

    // Log the execution
    await supabase.from('sync_audit_log').insert({
      sync_type: 'edge_function_daily_check',
      date_synced: new Date().toISOString().split('T')[0],
      success: true,
      error_message: null
    })

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Daily streak check completed',
        timestamp: new Date().toISOString(),
        result: data
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )
  } catch (error) {
    console.error('Edge function error:', error)

    // Log the error
    const supabase = createClient(supabaseUrl, supabaseServiceKey)
    await supabase.from('sync_audit_log').insert({
      sync_type: 'edge_function_daily_check',
      date_synced: new Date().toISOString().split('T')[0],
      success: false,
      error_message: error.message
    }).catch(console.error)

    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
        timestamp: new Date().toISOString()
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400
      }
    )
  }
})