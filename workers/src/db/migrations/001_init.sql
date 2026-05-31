-- ============================================================
-- 001_init.sql — Flatmate Meal Planner
-- Run: turso db shell flatmate-meals < 001_init.sql
-- ============================================================

-- PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

-- ─────────────────────────────────────────────
-- 1. MEALS
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS meals (
  id                TEXT    PRIMARY KEY,
  name              TEXT    NOT NULL,
  meal_type         TEXT    NOT NULL CHECK (meal_type IN ('Lunch', 'Dinner')),
  ingredients       TEXT    NOT NULL DEFAULT '[]',   -- JSON array of strings
  qty_per_person    TEXT    NOT NULL DEFAULT '{}',   -- JSON object { ingredient: "qty unit" }
  prep_steps        TEXT    NOT NULL DEFAULT '[]',   -- JSON array of strings
  category          TEXT,                            -- Dal | Paneer | Legume | Dry Sabzi | Gravy | Rice Dish | Seasonal
  tags              TEXT    NOT NULL DEFAULT '[]',   -- JSON array of strings
  times_cooked      INTEGER NOT NULL DEFAULT 0,
  times_offered     INTEGER NOT NULL DEFAULT 0,
  last_cooked_date  TEXT,                            -- ISO date YYYY-MM-DD
  is_active         INTEGER NOT NULL DEFAULT 1,
  created_at        TEXT    NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_meals_type     ON meals(meal_type);
CREATE INDEX IF NOT EXISTS idx_meals_category ON meals(category);
CREATE INDEX IF NOT EXISTS idx_meals_active   ON meals(is_active);
CREATE INDEX IF NOT EXISTS idx_meals_cooked   ON meals(last_cooked_date);

-- ─────────────────────────────────────────────
-- 2. USERS
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
  id              TEXT    PRIMARY KEY,
  name            TEXT    NOT NULL,
  telegram_id     TEXT    NOT NULL UNIQUE,
  preferences     TEXT    NOT NULL DEFAULT '[]',     -- JSON array of meal IDs (favourites)
  disliked_meals  TEXT    NOT NULL DEFAULT '[]',     -- JSON array of meal IDs
  is_active       INTEGER NOT NULL DEFAULT 1,
  created_at      TEXT    NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_users_telegram ON users(telegram_id);

-- ─────────────────────────────────────────────
-- 3. DAILY POLLS
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS daily_polls (
  id                TEXT    PRIMARY KEY,
  poll_date         TEXT    NOT NULL,                -- YYYY-MM-DD
  meal_type         TEXT    NOT NULL CHECK (meal_type IN ('Lunch', 'Dinner')),
  telegram_poll_id  TEXT,                            -- Telegram's internal poll ID
  candidate_1_id    TEXT    REFERENCES meals(id),
  candidate_2_id    TEXT    REFERENCES meals(id),
  winner_id         TEXT    REFERENCES meals(id),    -- NULL until poll closes
  votes_1           INTEGER NOT NULL DEFAULT 0,
  votes_2           INTEGER NOT NULL DEFAULT 0,
  status            TEXT    NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed', 'cancelled')),
  closed_at         TEXT,                            -- ISO datetime
  created_at        TEXT    NOT NULL DEFAULT (datetime('now')),
  UNIQUE(poll_date, meal_type)
);

CREATE INDEX IF NOT EXISTS idx_polls_date   ON daily_polls(poll_date);
CREATE INDEX IF NOT EXISTS idx_polls_status ON daily_polls(status);
CREATE INDEX IF NOT EXISTS idx_polls_tgid   ON daily_polls(telegram_poll_id);

-- ─────────────────────────────────────────────
-- 4. VOTES
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS votes (
  id              TEXT    PRIMARY KEY,
  poll_id         TEXT    NOT NULL REFERENCES daily_polls(id),
  user_id         TEXT    NOT NULL REFERENCES users(id),
  chosen_meal_id  TEXT    NOT NULL REFERENCES meals(id),
  voted_at        TEXT    NOT NULL DEFAULT (datetime('now')),
  UNIQUE(poll_id, user_id)                           -- one vote per user per poll
);

CREATE INDEX IF NOT EXISTS idx_votes_poll ON votes(poll_id);
CREATE INDEX IF NOT EXISTS idx_votes_user ON votes(user_id);

-- ─────────────────────────────────────────────
-- 5. INVENTORY
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS inventory (
  id                  TEXT    PRIMARY KEY,
  ingredient          TEXT    NOT NULL UNIQUE,
  current_stock       REAL    NOT NULL DEFAULT 0,
  minimum_threshold   REAL    NOT NULL DEFAULT 0,    -- reorder level
  unit                TEXT    NOT NULL DEFAULT 'g',  -- g | kg | L | ml | pcs
  updated_at          TEXT    NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_inventory_ingredient ON inventory(ingredient);

-- ─────────────────────────────────────────────
-- 6. MEAL HISTORY
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS meal_history (
  id                    TEXT    PRIMARY KEY,
  meal_id               TEXT    NOT NULL REFERENCES meals(id),
  cooked_date           TEXT    NOT NULL,            -- YYYY-MM-DD
  meal_type             TEXT    NOT NULL CHECK (meal_type IN ('Lunch', 'Dinner')),
  votes_received        INTEGER NOT NULL DEFAULT 0,
  total_possible_votes  INTEGER NOT NULL DEFAULT 3,
  created_at            TEXT    NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_history_meal ON meal_history(meal_id);
CREATE INDEX IF NOT EXISTS idx_history_date ON meal_history(cooked_date);

-- ─────────────────────────────────────────────
-- 7. PREP REMINDERS  (auto-generated nightly)
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS prep_reminders (
  id          TEXT    PRIMARY KEY,
  meal_id     TEXT    NOT NULL REFERENCES meals(id),
  for_date    TEXT    NOT NULL,                      -- YYYY-MM-DD (the cook date)
  reminder    TEXT    NOT NULL,                      -- e.g. "Soak rajma overnight"
  sent        INTEGER NOT NULL DEFAULT 0,            -- 0 = pending, 1 = sent
  created_at  TEXT    NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_reminders_date ON prep_reminders(for_date);
CREATE INDEX IF NOT EXISTS idx_reminders_sent ON prep_reminders(sent);

-- ============================================================
-- SEED DATA — Inventory staples
-- ============================================================
INSERT OR IGNORE INTO inventory (id, ingredient, current_stock, minimum_threshold, unit) VALUES
  ('inv_001', 'Rice',             2000, 500,  'g'),
  ('inv_002', 'Atta',             2000, 500,  'g'),
  ('inv_003', 'Rajma',            500,  100,  'g'),
  ('inv_004', 'Chana (kabuli)',    500,  100,  'g'),
  ('inv_005', 'Kaale chana',       300,  100,  'g'),
  ('inv_006', 'Arhar dal',         500,  100,  'g'),
  ('inv_007', 'Masoor dal',        500,  100,  'g'),
  ('inv_008', 'Moong dal',         300,  100,  'g'),
  ('inv_009', 'Paneer',            200,  100,  'g'),
  ('inv_010', 'Soyabean chunks',   200,  50,   'g'),
  ('inv_011', 'Oil',               500,  100,  'ml'),
  ('inv_012', 'Tomatoes',          400,  100,  'g'),
  ('inv_013', 'Onions',            500,  150,  'g'),
  ('inv_014', 'Garlic',            50,   20,   'g'),
  ('inv_015', 'Ginger',            50,   20,   'g'),
  ('inv_016', 'Turmeric',          50,   10,   'g'),
  ('inv_017', 'Red chilli powder', 50,   10,   'g'),
  ('inv_018', 'Coriander powder',  50,   10,   'g'),
  ('inv_019', 'Garam masala',      30,   10,   'g'),
  ('inv_020', 'Cumin seeds',       30,   10,   'g'),
  ('inv_021', 'Salt',              200,  50,   'g'),
  ('inv_022', 'Aloo (potatoes)',   1000, 250,  'g'),
  ('inv_023', 'Bhindi',            0,    0,    'g'),
  ('inv_024', 'Baingan',           0,    0,    'g'),
  ('inv_025', 'Shimla mirch',      0,    0,    'g'),
  ('inv_026', 'Matar (peas)',      200,  0,    'g'),
  ('inv_027', 'Palak',             0,    0,    'g'),
  ('inv_028', 'Dahi (yoghurt)',    200,  100,  'g'),
  ('inv_029', 'Fresh coriander',   30,   0,    'g'),
  ('inv_030', 'Ghee',              100,  30,   'g');

-- ============================================================
-- SEED DATA — Meals (14 pairs + 4 standalone)
-- ============================================================

-- LUNCH meals
INSERT OR IGNORE INTO meals (id, name, meal_type, ingredients, qty_per_person, prep_steps, category, tags) VALUES
(
  'meal_l_01', 'Arhar Dal + Bhindi', 'Lunch',
  '["Arhar dal","Bhindi","Tomato","Onion","Garlic","Ginger","Oil","Turmeric","Red chilli powder","Coriander powder","Cumin seeds","Salt","Fresh coriander"]',
  '{"Arhar dal":"80g","Bhindi":"100g","Tomato":"50g","Onion":"40g","Oil":"10ml"}',
  '["Wash and pressure-cook dal with turmeric (2 whistles)","Wash and chop bhindi, pat dry to reduce sliminess","Stir-fry bhindi in oil until crisp, set aside","Prepare tadka with cumin, onion, garlic, tomato and spices","Combine dal and bhindi, simmer 5 min","Garnish with fresh coriander"]',
  'Dal', '["North Indian","High Protein","Everyday"]'
),
(
  'meal_l_02', 'Chole', 'Lunch',
  '["Kabuli chana","Onion","Tomato","Garlic","Ginger","Oil","Bay leaf","Cinnamon","Cloves","Cumin seeds","Coriander powder","Cumin powder","Garam masala","Amchur","Red chilli powder","Turmeric","Salt","Fresh coriander"]',
  '{"Kabuli chana":"100g","Onion":"80g","Tomato":"80g","Oil":"15ml"}',
  '["NIGHT BEFORE: Soak kabuli chana in water for 8+ hours","Pressure-cook chana with salt and tea bag (for colour) — 6 whistles","Make onion-tomato masala, add whole spices and ginger-garlic paste","Add spice powders and cook until oil separates","Add cooked chana, simmer 15–20 min","Finish with amchur and garam masala, garnish coriander"]',
  'Legume', '["High Protein","Weekend Special","North Indian"]'
),
(
  'meal_l_03', 'Masoor Dal + Aloo Sukhe', 'Lunch',
  '["Masoor dal","Aloo","Tomato","Onion","Garlic","Ginger","Oil","Turmeric","Red chilli powder","Coriander powder","Cumin seeds","Dry mango powder","Salt","Fresh coriander"]',
  '{"Masoor dal":"80g","Aloo":"150g","Tomato":"50g","Oil":"10ml"}',
  '["Boil masoor dal with turmeric until soft (no soaking needed)","Boil potatoes, peel and cube","Heat oil, add cumin seeds, then onion-garlic-ginger","Add tomato and spices, cook masala","Finish dal with tadka","For sukhe aloo: heat oil with cumin, add boiled potatoes, spices, dry mango powder"]',
  'Dal', '["Quick Meal","Everyday","North Indian"]'
),
(
  'meal_l_04', 'Matar Paneer', 'Lunch',
  '["Paneer","Matar (peas)","Onion","Tomato","Garlic","Ginger","Oil","Cashews","Cream","Cumin seeds","Bay leaf","Coriander powder","Garam masala","Turmeric","Red chilli powder","Salt","Fresh coriander"]',
  '{"Paneer":"100g","Matar":"80g","Onion":"80g","Tomato":"80g","Oil":"15ml","Cream":"20ml"}',
  '["Blend soaked cashews with tomato-onion base for rich gravy","Sauté onion until golden, add ginger-garlic, cook masala","Add blended tomato-cashew paste, cook until oil separates","Add peas, simmer 5 min","Add paneer cubes (lightly fried or fresh), simmer 3 min","Finish with cream and garam masala"]',
  'Paneer', '["Rich","Weekend Special","North Indian"]'
),
(
  'meal_l_05', 'Mix Dal + Aloo Gobhi', 'Lunch',
  '["Arhar dal","Masoor dal","Moong dal","Aloo","Gobhi (cauliflower)","Onion","Tomato","Garlic","Ginger","Oil","Turmeric","Red chilli powder","Coriander powder","Cumin seeds","Salt","Fresh coriander"]',
  '{"Mixed dal":"90g","Aloo":"100g","Gobhi":"120g","Oil":"10ml"}',
  '["Mix all three dals, wash and pressure-cook with turmeric (2 whistles)","Chop aloo and gobhi into florets","Heat oil, fry gobhi until lightly browned, set aside","Sauté onion-garlic-tomato masala with spices","Add potatoes, cook 5 min, add gobhi, cover and cook","Temper dal separately, serve together"]',
  'Dal', '["Everyday","North Indian","High Protein"]'
),
(
  'meal_l_06', 'Rajma', 'Lunch',
  '["Rajma (kidney beans)","Onion","Tomato","Garlic","Ginger","Oil","Cumin seeds","Bay leaf","Coriander powder","Garam masala","Turmeric","Red chilli powder","Salt","Fresh coriander"]',
  '{"Rajma":"100g","Onion":"80g","Tomato":"80g","Oil":"12ml"}',
  '["NIGHT BEFORE: Soak rajma 8–10 hours","Pressure-cook soaked rajma with salt — 5 whistles","Sauté onions golden brown, add garlic-ginger paste","Add chopped tomatoes and all spices, cook until oil separates","Add cooked rajma with its water, simmer 15–20 min","Mash a few beans for thickness, garnish coriander"]',
  'Legume', '["High Protein","Weekend Special","North Indian"]'
),
(
  'meal_l_07', 'Arhar Dal + Baingan Bharta', 'Lunch',
  '["Arhar dal","Baingan (large)","Onion","Tomato","Garlic","Ginger","Oil","Turmeric","Red chilli powder","Coriander powder","Cumin seeds","Salt","Fresh coriander"]',
  '{"Arhar dal":"80g","Baingan":"200g","Onion":"80g","Tomato":"60g","Oil":"12ml"}',
  '["Roast baingan directly on flame until charred, cool and peel","Pressure-cook dal with turmeric (2 whistles)","Mash roasted baingan, keep aside","Sauté onion-garlic-ginger, add tomatoes and spices","Add mashed baingan, cook 5–7 min until well combined","Temper dal separately"]',
  'Dal', '["Smoky","North Indian","Everyday"]'
),
(
  'meal_l_08', 'Kadhi + Chips', 'Lunch',
  '["Dahi (yoghurt)","Besan (gram flour)","Aloo","Oil","Cumin seeds","Mustard seeds","Dried red chillies","Curry leaves","Turmeric","Red chilli powder","Salt","Fresh coriander"]',
  '{"Dahi":"200g","Besan":"30g","Aloo":"150g","Oil":"15ml"}',
  '["Whisk dahi with besan, turmeric and salt — no lumps","Add 2 cups water, bring to simmer whisking constantly — cook 20 min","For chips: slice aloo thin, deep fry or air-fry until crisp","Prepare tadka with cumin, mustard, dried chillies, curry leaves","Add tadka to kadhi, let chips soak briefly before serving"]',
  'Gravy', '["Comfort Food","North Indian","Unique"]'
),
(
  'meal_l_09', 'Palak Paneer + Boondi Raita', 'Lunch',
  '["Palak (spinach)","Paneer","Onion","Tomato","Garlic","Ginger","Oil","Cream","Dahi","Boondi","Cumin seeds","Coriander powder","Garam masala","Turmeric","Salt"]',
  '{"Palak":"200g","Paneer":"100g","Dahi":"100g","Boondi":"30g","Oil":"12ml"}',
  '["Blanch palak 2 min, refresh in cold water, blend smooth","Sauté onion-garlic-ginger, add tomatoes and spices","Add palak purée, cook 5 min","Add paneer cubes, simmer 3 min, finish with cream","For raita: whisk dahi, add boondi, salt, roasted cumin, coriander"]',
  'Paneer', '["Rich","Weekend Special","High Protein"]'
),
(
  'meal_l_10', 'Dhuli Moong Dal + Aloo Beans', 'Lunch',
  '["Dhuli moong dal","Aloo","French beans","Onion","Tomato","Garlic","Ginger","Oil","Turmeric","Red chilli powder","Coriander powder","Cumin seeds","Salt","Fresh coriander"]',
  '{"Moong dal":"80g","Aloo":"100g","Beans":"80g","Oil":"10ml"}',
  '["Wash and cook moong dal until soft (quick — 1 whistle or 15 min open)","Chop aloo and beans evenly","Heat oil, add cumin, sauté vegetables with spices","Cover and cook aloo-beans on medium heat 10–12 min","Temper dal with ghee-cumin tadka"]',
  'Dal', '["Light","Quick Meal","Everyday"]'
),
(
  'meal_l_11', 'Malai Kofta', 'Lunch',
  '["Paneer","Aloo","Onion","Tomato","Cashews","Cream","Milk","Oil","Cardamom","Cloves","Cinnamon","Garam masala","Red chilli powder","Coriander powder","Salt","Fresh coriander","Cornflour"]',
  '{"Paneer":"120g","Aloo":"100g","Cream":"40ml","Cashews":"20g","Oil":"15ml"}',
  '["Mash paneer and boiled potato together, season, shape into balls","Coat koftas in cornflour, deep fry until golden — set aside","Blend onion-tomato-cashew base after sautéing","Cook gravy with whole spices and spice powders until oil separates","Add cream, simmer 2 min — add koftas just before serving"]',
  'Paneer', '["Rich","Weekend Special","Restaurant Style"]'
),
(
  'meal_l_12', 'Kaale Chana', 'Lunch',
  '["Kaale chana","Onion","Tomato","Garlic","Ginger","Oil","Cumin seeds","Bay leaf","Coriander powder","Garam masala","Amchur","Turmeric","Red chilli powder","Salt","Fresh coriander"]',
  '{"Kaale chana":"100g","Onion":"80g","Tomato":"80g","Oil":"12ml"}',
  '["NIGHT BEFORE: Soak kaale chana 8–10 hours","Pressure-cook soaked chana with salt — 5–6 whistles","Sauté onion golden, add ginger-garlic paste","Add tomato and spices, cook masala until oil separates","Add cooked chana with water, simmer 15 min","Finish with amchur and garam masala"]',
  'Legume', '["High Protein","North Indian","Weekend Special"]'
),
(
  'meal_l_13', 'Dhuli Masoor Dal + Karela', 'Lunch',
  '["Masoor dal","Karela (bitter gourd)","Onion","Tomato","Garlic","Oil","Turmeric","Red chilli powder","Coriander powder","Cumin seeds","Amchur","Salt"]',
  '{"Masoor dal":"80g","Karela":"150g","Onion":"80g","Oil":"12ml"}',
  '["Slice karela thin, rub with salt, rest 20 min, squeeze to remove bitterness","Cook masoor dal with turmeric until soft","Shallow fry karela until crisp and browned","Sauté onion-garlic with spices, add karela, toss together","Temper dal, serve alongside karela"]',
  'Dal', '["Healthy","Bitter","Seasonal"]'
),
(
  'meal_l_14', 'Dal Makhani', 'Lunch',
  '["Kaale urad dal (whole)","Rajma","Onion","Tomato","Garlic","Ginger","Butter","Cream","Oil","Cumin seeds","Bay leaf","Coriander powder","Garam masala","Turmeric","Red chilli powder","Salt"]',
  '{"Urad dal":"80g","Rajma":"20g","Butter":"20g","Cream":"30ml","Oil":"10ml"}',
  '["NIGHT BEFORE: Soak urad dal + rajma together","Pressure-cook 8–10 whistles until very soft, mash slightly","Make rich onion-tomato-garlic-ginger masala in butter","Add dal to masala, simmer on LOW heat 30–45 min stirring","Add cream, finish with dollop of butter","Best made day before — flavour deepens overnight"]',
  'Dal', '["Rich","Weekend Special","Slow Cook","Restaurant Style"]'
);

-- DINNER meals
INSERT OR IGNORE INTO meals (id, name, meal_type, ingredients, qty_per_person, prep_steps, category, tags) VALUES
(
  'meal_d_01', 'Aloo Tamatar', 'Dinner',
  '["Aloo","Tomato","Oil","Cumin seeds","Turmeric","Red chilli powder","Coriander powder","Salt","Fresh coriander"]',
  '{"Aloo":"200g","Tomato":"100g","Oil":"8ml"}',
  '["Peel and cube potatoes","Heat oil, add cumin seeds, let splutter","Add potatoes, turmeric, salt — cover and cook 8 min","Add chopped tomatoes and remaining spices","Cover and cook 10 min until potatoes soft","Garnish with fresh coriander"]',
  'Dry Sabzi', '["Quick Meal","Everyday","Simple"]'
),
(
  'meal_d_02', 'Aloo Beans', 'Dinner',
  '["Aloo","French beans","Oil","Cumin seeds","Turmeric","Red chilli powder","Coriander powder","Amchur","Salt","Fresh coriander"]',
  '{"Aloo":"150g","Beans":"120g","Oil":"8ml"}',
  '["Chop beans into 1-inch pieces, cube potatoes similarly","Heat oil, add cumin seeds","Add potatoes, cover and cook 5 min on medium","Add beans and all spices, mix well","Cover and cook 12–15 min on low, stirring occasionally","Finish with amchur, garnish coriander"]',
  'Dry Sabzi', '["Quick Meal","Everyday","Light"]'
),
(
  'meal_d_03', 'Tehri', 'Dinner',
  '["Rice","Aloo","Matar","Carrot","Onion","Tomato","Oil","Ghee","Cumin seeds","Bay leaf","Cloves","Cinnamon","Turmeric","Red chilli powder","Garam masala","Salt","Fresh coriander"]',
  '{"Rice":"100g","Aloo":"80g","Matar":"50g","Carrot":"50g","Ghee":"8g"}',
  '["Wash and soak rice 20 min","Sauté onion in ghee+oil with whole spices","Add tomato and spice powders, cook 5 min","Add vegetables, toss to coat","Add soaked rice, 1.75x water, salt","Cover and cook on low until water absorbed (~15 min)"]',
  'Rice Dish', '["One Pot","Comfort Food","North Indian"]'
),
(
  'meal_d_04', 'Kaddu', 'Dinner',
  '["Kaddu (pumpkin)","Oil","Cumin seeds","Methi seeds","Dried red chillies","Turmeric","Red chilli powder","Coriander powder","Amchur","Jaggery","Salt"]',
  '{"Kaddu":"250g","Oil":"8ml","Jaggery":"5g"}',
  '["Peel and cube kaddu","Heat oil, add cumin and methi seeds, let crackle","Add dried chillies, then kaddu","Add spices, mix, cover and cook on low 15 min","Add jaggery and amchur for sweet-sour balance","Mash slightly before serving"]',
  'Dry Sabzi', '["Sweet-Sour","Seasonal","North Indian"]'
),
(
  'meal_d_05', 'Kofta', 'Dinner',
  '["Aloo","Paneer","Onion","Tomato","Cashews","Cream","Oil","Cardamom","Garam masala","Red chilli powder","Coriander powder","Salt","Cornflour","Fresh coriander"]',
  '{"Aloo":"100g","Paneer":"60g","Cream":"30ml","Oil":"12ml"}',
  '["Mash boiled potato with grated paneer, season, shape koftas","Coat in cornflour, deep fry golden — set aside","Blend sautéed onion-tomato-cashew, make gravy","Add cream and spices, simmer 5 min","Add koftas just before serving to keep shape"]',
  'Gravy', '["Rich","Weekend Special"]'
),
(
  'meal_d_06', 'Bhindi', 'Dinner',
  '["Bhindi","Oil","Cumin seeds","Onion","Tomato","Turmeric","Red chilli powder","Coriander powder","Amchur","Salt"]',
  '{"Bhindi":"200g","Onion":"60g","Oil":"10ml"}',
  '["Wash and completely dry bhindi, cut into rounds","Heat oil, fry bhindi on medium-high until crisp — DO NOT COVER","Add sliced onion, sauté 3 min","Add chopped tomato and spices","Cook uncovered 5 min, finish with amchur"]',
  'Dry Sabzi', '["Quick Meal","Everyday","Simple"]'
),
(
  'meal_d_07', 'Aloo Soyabean', 'Dinner',
  '["Aloo","Soyabean chunks","Onion","Tomato","Garlic","Ginger","Oil","Turmeric","Red chilli powder","Coriander powder","Garam masala","Salt","Fresh coriander"]',
  '{"Aloo":"150g","Soyabean chunks":"60g (dry weight)","Onion":"60g","Oil":"10ml"}',
  '["Soak soyabean chunks in hot water 15 min, squeeze out water","Cube potatoes","Sauté onion-garlic-ginger, add tomatoes and spices","Add potatoes, cook 5 min covered","Add squeezed soyabean chunks, mix well","Cover and cook 10 min until potatoes done"]',
  'Dry Sabzi', '["High Protein","Everyday","Budget"]'
),
(
  'meal_d_08', 'Aloo Shimla Mirch', 'Dinner',
  '["Aloo","Shimla mirch (capsicum)","Onion","Tomato","Oil","Cumin seeds","Turmeric","Red chilli powder","Coriander powder","Amchur","Salt"]',
  '{"Aloo":"150g","Shimla mirch":"100g","Onion":"60g","Oil":"8ml"}',
  '["Cube aloo, chop capsicum and onion into similar-sized pieces","Heat oil, add cumin","Add onion, sauté 3 min, add potatoes","Cook covered 8 min on medium","Add capsicum and spices, cook 5 min — capsicum should stay slightly crunchy","Finish with amchur"]',
  'Dry Sabzi', '["Colourful","Quick Meal","Everyday"]'
),
(
  'meal_d_09', 'Dahi Ke Aloo', 'Dinner',
  '["Aloo","Dahi","Oil","Cumin seeds","Mustard seeds","Hing","Turmeric","Red chilli powder","Coriander powder","Garam masala","Salt","Fresh coriander"]',
  '{"Aloo":"200g","Dahi":"100g","Oil":"8ml"}',
  '["Boil potatoes, peel and cube","Whisk dahi with turmeric and a pinch of salt","Heat oil, add cumin and mustard seeds, hing","Add potatoes, sauté 3 min","Add whisked dahi, stir continuously on medium heat","Cook 5–7 min until masala coats potatoes, garnish coriander"]',
  'Gravy', '["Tangy","Quick Meal","North Indian"]'
),
(
  'meal_d_10', 'Baingan Bharta', 'Dinner',
  '["Baingan (large)","Onion","Tomato","Garlic","Ginger","Oil","Cumin seeds","Turmeric","Red chilli powder","Coriander powder","Garam masala","Salt","Fresh coriander"]',
  '{"Baingan":"250g","Onion":"80g","Tomato":"80g","Oil":"12ml"}',
  '["Rub baingan with oil, roast on direct flame turning occasionally until fully charred","Cool, peel off skin, mash pulp — keep smoky juice","Sauté onion golden, add garlic-ginger paste","Add tomatoes and spices, cook until oil separates","Add mashed baingan, cook 8 min stirring","Garnish with fresh coriander"]',
  'Dry Sabzi', '["Smoky","North Indian","Everyday"]'
),
(
  'meal_d_11', 'Paneer Bhurji', 'Dinner',
  '["Paneer","Onion","Tomato","Capsicum","Garlic","Ginger","Oil","Cumin seeds","Turmeric","Red chilli powder","Garam masala","Salt","Fresh coriander"]',
  '{"Paneer":"120g","Onion":"80g","Tomato":"80g","Capsicum":"60g","Oil":"10ml"}',
  '["Crumble paneer coarsely by hand","Sauté onion-garlic-ginger on high heat 4 min","Add capsicum, toss 2 min","Add tomato and spices, cook 3–4 min","Add crumbled paneer, toss on high heat 3 min","Garnish coriander — serve immediately"]',
  'Paneer', '["Quick Meal","High Protein","Everyday"]'
),
(
  'meal_d_12', 'Rasam Rice', 'Dinner',
  '["Rice","Tomato","Tamarind","Garlic","Black pepper","Cumin seeds","Dried red chillies","Curry leaves","Mustard seeds","Oil","Turmeric","Hing","Salt","Fresh coriander"]',
  '{"Rice":"100g","Tomato":"100g","Tamarind":"10g","Oil":"8ml"}',
  '["Cook rice separately, keep warm","Soak tamarind in warm water, extract pulp","Boil tomatoes with tamarind water, smash tomatoes","Add garlic, pepper, cumin, turmeric, salt — simmer 10 min","Prepare tadka: mustard, cumin, dried chillies, curry leaves, hing in oil","Add tadka to rasam, serve poured over rice"]',
  'Rice Dish', '["South Indian","Comfort Food","Digestive"]'
),
(
  'meal_d_13', 'Mix Veg', 'Dinner',
  '["Gajar (carrot)","Shimla mirch","Pyaz (onion)","Aloo","Tomato","Oil","Cumin seeds","Turmeric","Red chilli powder","Coriander powder","Garam masala","Salt","Fresh coriander"]',
  '{"Mixed vegetables":"400g total","Onion":"80g","Tomato":"60g","Oil":"10ml"}',
  '["Chop all vegetables into even-sized pieces","Heat oil, add cumin seeds","Add onion, sauté 3 min, add garlic-ginger","Add tomato and spices, cook masala 4 min","Add harder vegetables first (carrot, potato), cover 8 min","Add capsicum and onion rings, toss, cook 5 min more"]',
  'Dry Sabzi', '["Colourful","Healthy","Everyday"]'
);

-- Standalone additional meals
INSERT OR IGNORE INTO meals (id, name, meal_type, ingredients, qty_per_person, prep_steps, category, tags) VALUES
(
  'meal_s_01', 'Kathal', 'Lunch',
  '["Raw kathal (jackfruit)","Onion","Tomato","Garlic","Ginger","Oil","Bay leaf","Cloves","Cinnamon","Turmeric","Red chilli powder","Coriander powder","Garam masala","Salt","Fresh coriander"]',
  '{"Raw kathal":"200g","Onion":"80g","Tomato":"80g","Oil":"15ml"}',
  '["Oil hands and knife before cutting kathal — sap is sticky","Boil kathal pieces until just tender, drain","Deep fry briefly or shallow fry until edges brown","Make rich onion-tomato masala with whole spices","Add kathal pieces, coat well, simmer 15 min","Best with paratha or rice"]',
  'Gravy', '["Weekend Special","Seasonal","Meat Alternative","North Indian"]'
),
(
  'meal_s_02', 'Aloo Baingan', 'Dinner',
  '["Aloo","Baingan","Onion","Tomato","Oil","Cumin seeds","Turmeric","Red chilli powder","Coriander powder","Amchur","Salt","Fresh coriander"]',
  '{"Aloo":"150g","Baingan":"150g","Onion":"60g","Oil":"10ml"}',
  '["Cube aloo and baingan into similar sized pieces","Heat oil, add cumin","Add onion, sauté 3 min","Add potatoes first, cover 5 min","Add baingan and spices, stir gently","Cover and cook 12 min until both soft","Finish with amchur, garnish coriander"]',
  'Dry Sabzi', '["Everyday","Quick Meal","North Indian"]'
),
(
  'meal_s_03', 'Pav Bhaji', 'Dinner',
  '["Aloo","Matar","Gobhi","Capsicum","Tomato","Onion","Butter","Oil","Pav bhaji masala","Turmeric","Red chilli powder","Ginger-garlic paste","Lemon","Pav","Salt","Fresh coriander"]',
  '{"Mixed vegetables":"300g","Butter":"25g","Pav":"2 pieces","Oil":"8ml"}',
  '["Boil aloo, matar and gobhi until very soft, mash coarsely","Sauté onion-ginger-garlic in butter-oil mixture","Add capsicum, cook 3 min, add tomatoes and masalas","Add mashed vegetables, mix and mash together on tawa","Cook 10–15 min adding water to get thick consistency","Toast pav on butter, serve with bhaji, onion, lemon, coriander"]',
  'Special', '["Weekend Special","Street Food Style","Quick Meal"]'
),
(
  'meal_s_04', 'Dum Aloo', 'Dinner',
  '["Small aloo","Dahi","Onion","Tomato","Cashews","Oil","Cumin seeds","Bay leaf","Cloves","Cardamom","Fennel powder","Ginger powder","Red chilli powder","Coriander powder","Garam masala","Salt","Fresh coriander"]',
  '{"Small aloo":"250g","Dahi":"80g","Cashews":"15g","Oil":"15ml"}',
  '["Parboil small potatoes, prick with fork all over","Deep fry or pan fry until golden brown","Blend sautéed onion-cashew-tomato for gravy base","Cook gravy with spices until oil separates","Whisk dahi, add slowly to gravy to prevent splitting","Add fried potatoes, cover and cook on dum (low heat) 15 min"]',
  'Gravy', '["Weekend Special","Rich","Kashmiri Style"]'
);

-- ============================================================
-- Verify
-- ============================================================
SELECT 'Tables created: ' || COUNT(*) FROM sqlite_master WHERE type='table';
SELECT 'Meals seeded: ' || COUNT(*) FROM meals;
SELECT 'Inventory items: ' || COUNT(*) FROM inventory;
