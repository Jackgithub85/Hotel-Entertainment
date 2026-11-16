-- Booking Platform Database Schema v1
-- Source: Phu luc 01 Hop dong 24156-SDS/AGN-IMV
-- Target database: PostgreSQL
-- Note: This is a detailed logical schema draft for development planning.

CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "citext";

CREATE TYPE service_type AS ENUM ('super_app', 'hour_of_joy', 'escape_room');
CREATE TYPE account_status AS ENUM ('active', 'inactive', 'blocked', 'deleted');
CREATE TYPE booking_service_type AS ENUM ('hotel', 'escape_room');
CREATE TYPE hotel_booking_type AS ENUM ('hourly', 'daily', 'overnight');
CREATE TYPE payment_status AS ENUM ('unpaid', 'pending', 'paid', 'failed', 'refunded', 'partially_refunded');
CREATE TYPE payment_provider AS ENUM ('vnpay', 'cash', 'manual');
CREATE TYPE discount_type AS ENUM ('percentage', 'fixed_amount');
CREATE TYPE sponsor_type AS ENUM ('platform', 'partner', 'co_sponsored');
CREATE TYPE promotion_status AS ENUM ('draft', 'scheduled', 'active', 'paused', 'expired', 'deleted');
CREATE TYPE settlement_status AS ENUM ('not_reconciled', 'in_dispute', 'completed');
CREATE TYPE settlement_payment_status AS ENUM ('unpaid', 'paid');
CREATE TYPE review_status AS ENUM ('pending', 'approved', 'rejected', 'withdrawn', 'hidden_by_user');

CREATE TABLE membership_tiers (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code text NOT NULL UNIQUE,
    name text NOT NULL,
    upgrade_spend_amount integer NOT NULL DEFAULT 0,
    maintain_spend_amount integer NOT NULL DEFAULT 0,
    reset_months integer NOT NULL DEFAULT 6,
    status account_status NOT NULL DEFAULT 'active',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE users (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code text NOT NULL UNIQUE,
    full_name text,
    phone text UNIQUE,
    email citext UNIQUE,
    province_id text,
    district_id text,
    gender text,
    dob date,
    language_code text NOT NULL DEFAULT 'vi',
    status account_status NOT NULL DEFAULT 'active',
    membership_tier_id uuid REFERENCES membership_tiers(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);

CREATE TABLE user_identities (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES users(id),
    provider text NOT NULL,
    provider_user_id text,
    email citext,
    phone text,
    password_hash text,
    verified_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (provider, provider_user_id)
);

CREATE TABLE otp_requests (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    target_type text NOT NULL,
    target_value text NOT NULL,
    purpose text NOT NULL,
    code_hash text NOT NULL,
    expires_at timestamptz NOT NULL,
    verified_at timestamptz,
    attempt_count integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE roles (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code text NOT NULL UNIQUE,
    name text NOT NULL,
    scope text NOT NULL,
    status account_status NOT NULL DEFAULT 'active',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE permissions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code text NOT NULL UNIQUE,
    module text NOT NULL,
    action text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE role_permissions (
    role_id uuid NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    permission_id uuid NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE staff_users (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    email citext NOT NULL UNIQUE,
    phone text,
    full_name text NOT NULL,
    owner_type text NOT NULL,
    owner_id uuid,
    role_id uuid REFERENCES roles(id),
    manager_id uuid REFERENCES staff_users(id),
    status account_status NOT NULL DEFAULT 'active',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);

CREATE TABLE hotels (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code text NOT NULL UNIQUE,
    name text NOT NULL,
    hotel_type text,
    description text,
    tax_code text,
    representative_name text,
    phone text,
    email citext,
    province_id text,
    district_id text,
    address text,
    latitude numeric(10,7),
    longitude numeric(10,7),
    rating_avg numeric(3,2) NOT NULL DEFAULT 0,
    review_count integer NOT NULL DEFAULT 0,
    status account_status NOT NULL DEFAULT 'active',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);

CREATE TABLE hotel_contracts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hotel_id uuid NOT NULL REFERENCES hotels(id),
    contract_no text NOT NULL,
    start_date date,
    end_date date,
    commission_rate numeric(5,2) NOT NULL DEFAULT 0,
    status text NOT NULL DEFAULT 'active',
    attachment_url text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE hotel_images (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hotel_id uuid NOT NULL REFERENCES hotels(id) ON DELETE CASCADE,
    url text NOT NULL,
    image_type text NOT NULL DEFAULT 'gallery',
    sort_order integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE hotel_room_types (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hotel_id uuid NOT NULL REFERENCES hotels(id),
    name text NOT NULL,
    area_sqm numeric(8,2),
    bed_type text,
    view_type text,
    memo text,
    total_rooms integer NOT NULL DEFAULT 0,
    status account_status NOT NULL DEFAULT 'active',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);

CREATE TABLE hotel_room_rates (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    room_type_id uuid NOT NULL REFERENCES hotel_room_types(id) ON DELETE CASCADE,
    booking_type hotel_booking_type NOT NULL,
    base_price integer NOT NULL DEFAULT 0,
    first_hour_price integer,
    extra_hour_price integer,
    max_hours integer,
    currency text NOT NULL DEFAULT 'VND',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (room_type_id, booking_type)
);

CREATE TABLE room_blocks (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    room_type_id uuid NOT NULL REFERENCES hotel_room_types(id),
    booking_type hotel_booking_type,
    start_at timestamptz NOT NULL,
    end_at timestamptz NOT NULL,
    reason text,
    created_by uuid REFERENCES staff_users(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    CHECK (end_at > start_at)
);

CREATE TABLE hotel_products (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hotel_id uuid NOT NULL REFERENCES hotels(id),
    category_name text,
    name text NOT NULL,
    image_url text,
    price integer NOT NULL DEFAULT 0,
    need_prepare_before_day boolean NOT NULL DEFAULT false,
    status account_status NOT NULL DEFAULT 'active',
    approval_status text NOT NULL DEFAULT 'pending',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE escape_merchants (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code text NOT NULL UNIQUE,
    name text NOT NULL,
    tax_code text,
    phone text,
    email citext,
    bank_account text,
    bank_name text,
    status account_status NOT NULL DEFAULT 'active',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);

CREATE TABLE escape_locations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_id uuid NOT NULL REFERENCES escape_merchants(id),
    name text NOT NULL,
    description text,
    province_id text,
    district_id text,
    address text,
    latitude numeric(10,7),
    longitude numeric(10,7),
    rating_avg numeric(3,2) NOT NULL DEFAULT 0,
    review_count integer NOT NULL DEFAULT 0,
    status account_status NOT NULL DEFAULT 'active',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);

CREATE TABLE escape_themes (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    location_id uuid NOT NULL REFERENCES escape_locations(id),
    name text NOT NULL,
    description text,
    min_players integer NOT NULL DEFAULT 1,
    max_players integer NOT NULL DEFAULT 1,
    duration_minutes integer NOT NULL DEFAULT 60,
    base_price integer NOT NULL DEFAULT 0,
    status account_status NOT NULL DEFAULT 'active',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    CHECK (max_players >= min_players)
);

CREATE TABLE escape_sessions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    theme_id uuid NOT NULL REFERENCES escape_themes(id),
    start_at timestamptz NOT NULL,
    end_at timestamptz NOT NULL,
    capacity_min integer NOT NULL,
    capacity_max integer NOT NULL,
    booked_count integer NOT NULL DEFAULT 0,
    base_price integer NOT NULL DEFAULT 0,
    status text NOT NULL DEFAULT 'open',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CHECK (end_at > start_at),
    CHECK (capacity_max >= capacity_min)
);

CREATE TABLE promotions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code text NOT NULL UNIQUE,
    name text NOT NULL,
    service_type booking_service_type NOT NULL,
    promotion_type text NOT NULL,
    sponsor_type sponsor_type NOT NULL,
    discount_type discount_type NOT NULL,
    discount_value integer NOT NULL,
    max_discount integer,
    min_order_amount integer NOT NULL DEFAULT 0,
    start_at timestamptz NOT NULL,
    end_at timestamptz NOT NULL,
    usage_limit integer,
    per_user_limit integer,
    refundable_allowed boolean NOT NULL DEFAULT true,
    status promotion_status NOT NULL DEFAULT 'draft',
    created_by uuid REFERENCES staff_users(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CHECK (end_at > start_at)
);

CREATE TABLE promotion_targets (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    promotion_id uuid NOT NULL REFERENCES promotions(id) ON DELETE CASCADE,
    target_type text NOT NULL,
    target_id uuid,
    province_id text,
    district_id text,
    hotel_type text,
    membership_tier_id uuid REFERENCES membership_tiers(id),
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE user_coupons (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES users(id),
    promotion_id uuid NOT NULL REFERENCES promotions(id),
    saved_at timestamptz NOT NULL DEFAULT now(),
    used_at timestamptz,
    status text NOT NULL DEFAULT 'saved',
    UNIQUE (user_id, promotion_id)
);

CREATE TABLE bookings (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code text NOT NULL UNIQUE,
    service_type booking_service_type NOT NULL,
    user_id uuid NOT NULL REFERENCES users(id),
    hotel_id uuid REFERENCES hotels(id),
    room_type_id uuid REFERENCES hotel_room_types(id),
    escape_location_id uuid REFERENCES escape_locations(id),
    escape_theme_id uuid REFERENCES escape_themes(id),
    escape_session_id uuid REFERENCES escape_sessions(id),
    booking_type hotel_booking_type,
    checkin_at timestamptz NOT NULL,
    checkout_at timestamptz,
    player_count integer,
    status text NOT NULL,
    payment_status payment_status NOT NULL DEFAULT 'unpaid',
    total_amount integer NOT NULL DEFAULT 0,
    partner_discount_amount integer NOT NULL DEFAULT 0,
    platform_discount_amount integer NOT NULL DEFAULT 0,
    coin_discount_amount integer NOT NULL DEFAULT 0,
    final_amount integer NOT NULL DEFAULT 0,
    cancellation_reason text,
    note text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);

CREATE TABLE booking_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id uuid NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    item_type text NOT NULL,
    item_id uuid,
    name text NOT NULL,
    quantity integer NOT NULL DEFAULT 1,
    unit_price integer NOT NULL DEFAULT 0,
    total_price integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE booking_discounts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id uuid NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    promotion_id uuid REFERENCES promotions(id),
    user_coupon_id uuid REFERENCES user_coupons(id),
    sponsor_type sponsor_type NOT NULL,
    discount_amount integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE payments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id uuid NOT NULL REFERENCES bookings(id),
    provider payment_provider NOT NULL,
    method text NOT NULL,
    amount integer NOT NULL,
    transaction_ref text,
    status payment_status NOT NULL DEFAULT 'pending',
    paid_at timestamptz,
    raw_response_json jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE refunds (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id uuid NOT NULL REFERENCES payments(id),
    booking_id uuid NOT NULL REFERENCES bookings(id),
    amount integer NOT NULL,
    reason text,
    status text NOT NULL DEFAULT 'pending',
    provider_ref text,
    processed_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE booking_status_histories (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id uuid NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    from_status text,
    to_status text NOT NULL,
    reason text,
    actor_type text NOT NULL,
    actor_id uuid,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE coin_wallets (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL UNIQUE REFERENCES users(id),
    balance integer NOT NULL DEFAULT 0,
    lifetime_earned integer NOT NULL DEFAULT 0,
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE coin_rules (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tier_id uuid NOT NULL REFERENCES membership_tiers(id),
    rule_type text NOT NULL,
    spend_amount integer,
    earn_coin integer,
    redeem_value integer,
    expiry_rule text,
    status account_status NOT NULL DEFAULT 'active',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE coin_transactions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    wallet_id uuid NOT NULL REFERENCES coin_wallets(id),
    booking_id uuid REFERENCES bookings(id),
    transaction_type text NOT NULL,
    coin_amount integer NOT NULL,
    money_value integer,
    expires_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE reviews (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    service_type booking_service_type NOT NULL,
    booking_id uuid NOT NULL REFERENCES bookings(id),
    user_id uuid NOT NULL REFERENCES users(id),
    target_type text NOT NULL,
    target_id uuid NOT NULL,
    rating integer NOT NULL,
    content text,
    status review_status NOT NULL DEFAULT 'pending',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CHECK (rating BETWEEN 1 AND 5)
);

CREATE TABLE review_criteria_scores (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    review_id uuid NOT NULL REFERENCES reviews(id) ON DELETE CASCADE,
    criteria_code text NOT NULL,
    score integer NOT NULL,
    CHECK (score BETWEEN 1 AND 5)
);

CREATE TABLE sensitive_keywords (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    keyword text NOT NULL,
    language_code text NOT NULL DEFAULT 'vi',
    status account_status NOT NULL DEFAULT 'active',
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (keyword, language_code)
);

CREATE TABLE partners (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    partner_type text NOT NULL,
    ref_id uuid NOT NULL,
    name text NOT NULL,
    bank_account text,
    bank_name text,
    status account_status NOT NULL DEFAULT 'active',
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE settlement_periods (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    partner_id uuid NOT NULL REFERENCES partners(id),
    service_type booking_service_type NOT NULL,
    period_no text NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL,
    due_date date,
    settlement_status settlement_status NOT NULL DEFAULT 'not_reconciled',
    payment_status settlement_payment_status NOT NULL DEFAULT 'unpaid',
    total_debt integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (partner_id, service_type, period_no)
);

CREATE TABLE settlement_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    settlement_period_id uuid NOT NULL REFERENCES settlement_periods(id) ON DELETE CASCADE,
    booking_id uuid NOT NULL REFERENCES bookings(id),
    room_amount integer NOT NULL DEFAULT 0,
    product_amount integer NOT NULL DEFAULT 0,
    surcharge_amount integer NOT NULL DEFAULT 0,
    platform_discount integer NOT NULL DEFAULT 0,
    partner_discount integer NOT NULL DEFAULT 0,
    commission_amount integer NOT NULL DEFAULT 0,
    debt_amount integer NOT NULL DEFAULT 0,
    status text NOT NULL DEFAULT 'confirmed',
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (settlement_period_id, booking_id)
);

CREATE TABLE settlement_disputes (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    settlement_item_id uuid NOT NULL REFERENCES settlement_items(id),
    reason_type text NOT NULL,
    reason_text text NOT NULL,
    status text NOT NULL DEFAULT 'open',
    admin_response text,
    resolved_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE posts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id uuid,
    title text NOT NULL,
    content text NOT NULL,
    service_type service_type NOT NULL,
    status account_status NOT NULL DEFAULT 'active',
    published_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE notifications (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_type text NOT NULL,
    recipient_id uuid NOT NULL,
    service_type service_type,
    title text NOT NULL,
    body text NOT NULL,
    notification_type text NOT NULL,
    read_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE audit_logs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_type text NOT NULL,
    actor_id uuid,
    action text NOT NULL,
    entity_type text NOT NULL,
    entity_id uuid,
    before_json jsonb,
    after_json jsonb,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_users_status ON users(status);
CREATE INDEX idx_hotels_location_status ON hotels(province_id, district_id, status);
CREATE INDEX idx_hotels_rating ON hotels(rating_avg DESC);
CREATE INDEX idx_room_rates_type ON hotel_room_rates(room_type_id, booking_type);
CREATE INDEX idx_escape_locations_location_status ON escape_locations(province_id, district_id, status);
CREATE INDEX idx_escape_sessions_theme_time ON escape_sessions(theme_id, start_at, end_at, status);
CREATE INDEX idx_bookings_user_service_status ON bookings(user_id, service_type, status, checkin_at);
CREATE INDEX idx_bookings_hotel_status_time ON bookings(hotel_id, status, checkin_at);
CREATE INDEX idx_bookings_escape_session_status ON bookings(escape_session_id, status);
CREATE INDEX idx_payments_booking_status ON payments(booking_id, status);
CREATE INDEX idx_promotions_service_status_time ON promotions(service_type, status, start_at, end_at);
CREATE INDEX idx_settlement_periods_partner_status ON settlement_periods(partner_id, settlement_status, payment_status, end_date);
CREATE INDEX idx_reviews_target_status ON reviews(target_type, target_id, status);
CREATE INDEX idx_audit_logs_entity ON audit_logs(entity_type, entity_id, created_at DESC);
