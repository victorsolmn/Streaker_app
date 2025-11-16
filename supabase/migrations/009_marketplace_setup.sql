-- Migration 009: Marketplace and Premium Membership Setup
-- Created: November 15, 2025
-- Purpose: Create tables for supplement marketplace and premium memberships

-- ============================================
-- 1. PRODUCT CATEGORIES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.product_categories (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  description TEXT,
  icon TEXT, -- Icon name from Material Icons
  display_order INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS
ALTER TABLE public.product_categories ENABLE ROW LEVEL SECURITY;

-- Allow public read access
CREATE POLICY "Allow public read access to product_categories"
ON public.product_categories FOR SELECT
USING (is_active = true);

-- ============================================
-- 2. PRODUCTS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.products (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  category_id UUID REFERENCES public.product_categories(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  brand TEXT NOT NULL,
  description TEXT,
  image_url TEXT,
  regular_price DECIMAL(10, 2) NOT NULL,
  premium_price DECIMAL(10, 2) NOT NULL,
  discount_percentage INTEGER DEFAULT 25,
  stock_quantity INTEGER DEFAULT 0,
  is_featured BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  serving_size TEXT, -- e.g., "30 servings", "1kg"
  flavor TEXT, -- e.g., "Chocolate", "Vanilla"
  rating DECIMAL(3, 2) DEFAULT 0.0, -- Average rating out of 5.0
  review_count INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

-- Allow public read access to active products
CREATE POLICY "Allow public read access to products"
ON public.products FOR SELECT
USING (is_active = true);

-- Create indexes for performance
CREATE INDEX idx_products_category ON public.products(category_id);
CREATE INDEX idx_products_featured ON public.products(is_featured) WHERE is_featured = true;
CREATE INDEX idx_products_active ON public.products(is_active) WHERE is_active = true;

-- ============================================
-- 3. PREMIUM MEMBERSHIPS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.premium_memberships (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  plan_type TEXT NOT NULL CHECK (plan_type IN ('monthly', 'quarterly', 'annual')),
  status TEXT NOT NULL CHECK (status IN ('active', 'cancelled', 'expired', 'trial')) DEFAULT 'trial',
  start_date TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  end_date TIMESTAMP WITH TIME ZONE NOT NULL,
  trial_end_date TIMESTAMP WITH TIME ZONE,
  price_paid DECIMAL(10, 2) NOT NULL,
  discount_percentage INTEGER DEFAULT 25,
  auto_renew BOOLEAN DEFAULT true,
  payment_method TEXT,
  razorpay_subscription_id TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  UNIQUE(user_id, status) -- One active membership per user
);

-- Enable RLS
ALTER TABLE public.premium_memberships ENABLE ROW LEVEL SECURITY;

-- Users can only see their own memberships
CREATE POLICY "Users can view own premium memberships"
ON public.premium_memberships FOR SELECT
USING (auth.uid() = user_id);

-- Users can insert their own memberships
CREATE POLICY "Users can create own premium memberships"
ON public.premium_memberships FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Users can update their own memberships
CREATE POLICY "Users can update own premium memberships"
ON public.premium_memberships FOR UPDATE
USING (auth.uid() = user_id);

-- Create index for user lookups
CREATE INDEX idx_premium_memberships_user ON public.premium_memberships(user_id);
CREATE INDEX idx_premium_memberships_status ON public.premium_memberships(status);

-- ============================================
-- 4. SHOPPING CART TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.shopping_cart (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  product_id UUID REFERENCES public.products(id) ON DELETE CASCADE NOT NULL,
  quantity INTEGER DEFAULT 1 CHECK (quantity > 0),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  UNIQUE(user_id, product_id) -- One entry per product per user
);

-- Enable RLS
ALTER TABLE public.shopping_cart ENABLE ROW LEVEL SECURITY;

-- Users can only see their own cart
CREATE POLICY "Users can view own cart"
ON public.shopping_cart FOR SELECT
USING (auth.uid() = user_id);

-- Users can manage their own cart
CREATE POLICY "Users can insert into own cart"
ON public.shopping_cart FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own cart"
ON public.shopping_cart FOR UPDATE
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete from own cart"
ON public.shopping_cart FOR DELETE
USING (auth.uid() = user_id);

-- Create indexes
CREATE INDEX idx_shopping_cart_user ON public.shopping_cart(user_id);

-- ============================================
-- 5. ORDERS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  order_number TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL CHECK (status IN ('pending', 'confirmed', 'processing', 'ready', 'completed', 'cancelled')) DEFAULT 'pending',
  total_amount DECIMAL(10, 2) NOT NULL,
  premium_discount DECIMAL(10, 2) DEFAULT 0.00,
  final_amount DECIMAL(10, 2) NOT NULL,
  is_premium_order BOOLEAN DEFAULT false,
  payment_method TEXT,
  payment_status TEXT CHECK (payment_status IN ('pending', 'paid', 'failed', 'refunded')) DEFAULT 'pending',
  razorpay_order_id TEXT,
  razorpay_payment_id TEXT,
  delivery_method TEXT CHECK (delivery_method IN ('pickup', 'delivery')) DEFAULT 'pickup',
  delivery_address TEXT,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

-- Users can only see their own orders
CREATE POLICY "Users can view own orders"
ON public.orders FOR SELECT
USING (auth.uid() = user_id);

-- Users can create their own orders
CREATE POLICY "Users can create own orders"
ON public.orders FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Create indexes
CREATE INDEX idx_orders_user ON public.orders(user_id);
CREATE INDEX idx_orders_status ON public.orders(status);
CREATE INDEX idx_orders_created ON public.orders(created_at DESC);

-- ============================================
-- 6. ORDER ITEMS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.order_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID REFERENCES public.orders(id) ON DELETE CASCADE NOT NULL,
  product_id UUID REFERENCES public.products(id) ON DELETE SET NULL,
  product_name TEXT NOT NULL, -- Store product name in case product is deleted
  product_brand TEXT NOT NULL,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  unit_price DECIMAL(10, 2) NOT NULL,
  total_price DECIMAL(10, 2) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

-- Users can see items for their own orders
CREATE POLICY "Users can view own order items"
ON public.order_items FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.orders
    WHERE orders.id = order_items.order_id
    AND orders.user_id = auth.uid()
  )
);

-- Create index
CREATE INDEX idx_order_items_order ON public.order_items(order_id);

-- ============================================
-- 7. HELPER FUNCTIONS
-- ============================================

-- Function to check if user is premium member
CREATE OR REPLACE FUNCTION public.is_premium_member(p_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.premium_memberships
    WHERE user_id = p_user_id
    AND status = 'active'
    AND end_date > timezone('utc'::text, now())
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user's premium discount percentage
CREATE OR REPLACE FUNCTION public.get_premium_discount(p_user_id UUID)
RETURNS INTEGER AS $$
DECLARE
  v_discount INTEGER;
BEGIN
  SELECT discount_percentage INTO v_discount
  FROM public.premium_memberships
  WHERE user_id = p_user_id
  AND status = 'active'
  AND end_date > timezone('utc'::text, now())
  LIMIT 1;

  RETURN COALESCE(v_discount, 0);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to generate order number
CREATE OR REPLACE FUNCTION public.generate_order_number()
RETURNS TEXT AS $$
DECLARE
  v_order_number TEXT;
  v_count INTEGER;
BEGIN
  -- Format: STR-YYYYMMDD-XXXX (e.g., STR-20251115-0001)
  v_order_number := 'STR-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-';

  -- Get count of orders today
  SELECT COUNT(*) INTO v_count
  FROM public.orders
  WHERE created_at >= DATE_TRUNC('day', NOW());

  v_order_number := v_order_number || LPAD((v_count + 1)::TEXT, 4, '0');

  RETURN v_order_number;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 8. INSERT SAMPLE CATEGORIES
-- ============================================
INSERT INTO public.product_categories (name, slug, description, icon, display_order) VALUES
('Protein', 'protein', 'Whey, Casein, Plant-based proteins for muscle building', 'fitness_center', 1),
('Pre-Workout', 'pre-workout', 'Energy and pump boosters for intense training', 'bolt', 2),
('Creatine', 'creatine', 'Creatine monohydrate and blends for strength', 'offline_bolt', 3),
('Post-Workout', 'post-workout', 'Recovery supplements and BCAAs', 'restore', 4),
('Combo Packs', 'combo-packs', 'Value bundles and stack deals', 'card_giftcard', 5);

-- ============================================
-- 9. VERIFICATION
-- ============================================
DO $$
BEGIN
  RAISE NOTICE '✅ Migration 009 completed successfully';
  RAISE NOTICE '📊 Tables created:';
  RAISE NOTICE '   - product_categories';
  RAISE NOTICE '   - products';
  RAISE NOTICE '   - premium_memberships';
  RAISE NOTICE '   - shopping_cart';
  RAISE NOTICE '   - orders';
  RAISE NOTICE '   - order_items';
  RAISE NOTICE '🔧 Helper functions created:';
  RAISE NOTICE '   - is_premium_member()';
  RAISE NOTICE '   - get_premium_discount()';
  RAISE NOTICE '   - generate_order_number()';
  RAISE NOTICE '📦 Sample categories inserted: 5 categories';
END $$;
