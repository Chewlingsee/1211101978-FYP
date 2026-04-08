import sys
import os
import logging
from datetime import date, timedelta

# Append parent directory to import db_functions
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from db_functions import connect_to_database

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def finalize_meal_status_and_logs():
    conn = None
    cursor = None
    results = {
        'total_users_to_finalize': 0,
        'meals_updated': 0,
        'logs_updated': 0,
        'errors': []
    }

    try:
        conn = connect_to_database()
        cursor = conn.cursor()

        today = date.today()
        yesterday = today - timedelta(days=1)
        logger.info(f"Finalizing meals for date: {yesterday}")

        cursor.execute("""
            SELECT DISTINCT w.id, w.user_id
            FROM weekly_diet_plan w
            JOIN daily_meal_plan m ON w.id = m.weekly_plan_id
            WHERE w.is_active = TRUE
              AND m.plan_date = %s
              AND m.status NOT IN ('completed', 'skipped')
        """, (yesterday,))
        plans = cursor.fetchall()
        results['total_users_to_finalize'] = len(plans)
        logger.info(f"Users to finalize: {len(plans)}")

        for weekly_plan_id, user_id in plans:
            try:
                logger.info(f"Processing User: {user_id}, Plan ID: {weekly_plan_id}")

                # Step 1: Mark uncompleted meals as skipped
                cursor.execute("""
                    UPDATE daily_meal_plan
                    SET status = 'skipped'
                    WHERE weekly_plan_id = %s AND plan_date = %s
                    AND (status IS NULL OR status NOT IN ('completed', 'skipped'))
                """, (weekly_plan_id, yesterday))
                results['meals_updated'] += cursor.rowcount

                # Step 2: Get actual totals from completed meals
                cursor.execute("""
                    SELECT COALESCE(SUM(target_cal), 0),
                           COALESCE(SUM(target_fat), 0),
                           COALESCE(SUM(target_carbs), 0),
                           COALESCE(SUM(target_protein), 0)
                    FROM daily_meal_plan
                    WHERE weekly_plan_id = %s AND plan_date = %s AND status = 'completed'
                """, (weekly_plan_id, yesterday))
                cal, fat, carbs, protein = cursor.fetchone()

                # Step 3: Insert/update daily_log
                cursor.execute("""
                    INSERT INTO daily_log (
                        user_id, log_date,
                        total_calories, total_fat, total_carbs, total_protein,
                        actual_calories, actual_fat, actual_carbs, actual_protein,
                        created_at, updated_at
                    )
                    VALUES (
                        %s, %s,
                        (SELECT COALESCE(SUM(target_cal), 0) FROM daily_meal_plan WHERE weekly_plan_id = %s AND plan_date = %s),
                        (SELECT COALESCE(SUM(target_fat), 0) FROM daily_meal_plan WHERE weekly_plan_id = %s AND plan_date = %s),
                        (SELECT COALESCE(SUM(target_carbs), 0) FROM daily_meal_plan WHERE weekly_plan_id = %s AND plan_date = %s),
                        (SELECT COALESCE(SUM(target_protein), 0) FROM daily_meal_plan WHERE weekly_plan_id = %s AND plan_date = %s),
                        %s, %s, %s, %s,
                        NOW(), NOW()
                    )
                    ON DUPLICATE KEY UPDATE
                        actual_calories = VALUES(actual_calories),
                        actual_fat = VALUES(actual_fat),
                        actual_carbs = VALUES(actual_carbs),
                        actual_protein = VALUES(actual_protein),
                        updated_at = NOW()
                """, (
                    user_id, yesterday,
                    weekly_plan_id, yesterday,
                    weekly_plan_id, yesterday,
                    weekly_plan_id, yesterday,
                    weekly_plan_id, yesterday,
                    cal, fat, carbs, protein
                ))
                results['logs_updated'] += 1
                logger.info(f"Updated daily_log for user {user_id}")

            except Exception as user_error:
                logger.error(f"Error processing user {user_id}: {user_error}")
                results['errors'].append(f"User {user_id}: {user_error}")
                conn.rollback()
                continue

        conn.commit()
        logger.info("Finalization completed.")
        return results

    except Exception as global_error:
        logger.error(f"Global error: {global_error}")
        if conn:
            conn.rollback()
        results['errors'].append(f"Global error: {str(global_error)}")
        return results

    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()


# Run when called directly
if __name__ == "__main__":
    summary = finalize_meal_status_and_logs()
    print("======== FINALIZATION SUMMARY ========")
    print(f"Total Users Processed: {summary['total_users_processed']}")
    print(f"Meals Updated: {summary['meals_updated']}")
    print(f"Logs Updated: {summary['logs_updated']}")
    print(f"Errors: {len(summary['errors'])}")
    if summary['errors']:
        for error in summary['errors']:
            print(f" - {error}")
