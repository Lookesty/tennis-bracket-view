-- Update gender values in tennis_events categories
UPDATE tennis_events
SET categories = (
  SELECT jsonb_agg(
    CASE 
      WHEN cat->>'gender' = 'mens' THEN jsonb_set(cat, '{gender}', '"men"')
      WHEN cat->>'gender' = 'womens' THEN jsonb_set(cat, '{gender}', '"women"')
      ELSE cat
    END
  )
  FROM jsonb_array_elements(categories) cat
)
WHERE categories IS NOT NULL;

-- Update gender values in registration_categories
UPDATE registration_categories
SET category = 
  CASE 
    WHEN category->>'gender' = 'mens' THEN jsonb_set(category, '{gender}', '"men"')
    WHEN category->>'gender' = 'womens' THEN jsonb_set(category, '{gender}', '"women"')
    ELSE category
  END
WHERE category IS NOT NULL; 