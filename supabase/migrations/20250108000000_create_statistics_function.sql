-- Create function to get monthly spending statistics for a group
CREATE OR REPLACE FUNCTION get_group_monthly_statistics(
  group_id_param UUID,
  start_date_param TIMESTAMP,
  end_date_param TIMESTAMP
)
RETURNS TABLE (
  month TEXT,
  email TEXT,
  display_name TEXT,
  total_spent NUMERIC
) 
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    DATE_TRUNC('month', e.expense_date)::TEXT as month,
    ees.email,
    COALESCE(u.display_name, ees.email) as display_name,
    SUM(ee.amount * (ees.percentage / 100)) as total_spent
  FROM expense e
  JOIN expense_entry ee ON e.id = ee.expense_id  
  JOIN expense_entry_share ees ON ee.id = ees.expense_entry_id
  LEFT JOIN "user" u ON ees.email = u.email
  WHERE e.group_id = group_id_param
    AND e.expense_date >= start_date_param
    AND e.expense_date <= end_date_param
    AND e.is_paid_back_row = false
  GROUP BY DATE_TRUNC('month', e.expense_date), ees.email, u.display_name
  ORDER BY month DESC, total_spent DESC;
END;
$$;
