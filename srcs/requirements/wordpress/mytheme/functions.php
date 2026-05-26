<?php
/**
 * MyTheme Functions
 *
 * Creates a custom 'guest_comments' table in MariaDB
 * and provides helper functions to insert/retrieve comments.
 */

// ── Create table on theme activation ──
function mytheme_create_comments_table() {
    global $wpdb;
    $table = $wpdb->prefix . 'guest_comments';
    $charset = $wpdb->get_charset_collate();

    $sql = "CREATE TABLE IF NOT EXISTS $table (
        id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        author     VARCHAR(100)  NOT NULL,
        message    TEXT          NOT NULL,
        created_at DATETIME      DEFAULT CURRENT_TIMESTAMP
    ) $charset;";

    require_once ABSPATH . 'wp-admin/includes/upgrade.php';
    dbDelta($sql);
}
add_action('after_switch_theme', 'mytheme_create_comments_table');

// Also ensure table exists on every load (safe for first run)
add_action('init', 'mytheme_create_comments_table');

// ── Insert a comment ──
function mytheme_insert_comment($author, $message) {
    global $wpdb;
    $table = $wpdb->prefix . 'guest_comments';

    return $wpdb->insert($table, [
        'author'  => sanitize_text_field($author),
        'message' => sanitize_textarea_field($message),
    ]);
}

// ── Get all comments (newest first) ──
function mytheme_get_comments($limit = 50) {
    global $wpdb;
    $table = $wpdb->prefix . 'guest_comments';

    return $wpdb->get_results(
        $wpdb->prepare("SELECT * FROM $table ORDER BY created_at DESC LIMIT %d", $limit)
    );
}

// ── Handle form submission ──
function mytheme_handle_comment_form() {
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['mytheme_comment'])) {
        // Verify nonce for security
        if (!wp_verify_nonce($_POST['_wpnonce'], 'mytheme_comment_nonce')) {
            return;
        }

        $author  = trim($_POST['comment_author'] ?? '');
        $message = trim($_POST['comment_message'] ?? '');

        if ($author !== '' && $message !== '') {
            mytheme_insert_comment($author, $message);
            // Redirect to prevent form resubmission on refresh
            // Use REQUEST_URI base so it works with both localhost and domain
            $base = strtok($_SERVER['REQUEST_URI'], '?');
            wp_redirect($base . '?commented=1');
            exit;
        }
    }
}
add_action('template_redirect', 'mytheme_handle_comment_form');
