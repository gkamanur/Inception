<?php get_header(); ?>

<h1>INCEPTION</h1>
<p>Custom WordPress theme running inside Docker</p>

<!-- ── Success message ── -->
<?php if (isset($_GET['commented'])): ?>
    <p class="success">✅ Comment posted!</p>
<?php endif; ?>

<!-- ══════════════════════════════════════ -->
<!--           COMMENT FORM               -->
<!-- ══════════════════════════════════════ -->
<section class="comment-form">
    <h2>💬 Leave a Comment</h2>
    <form method="POST" action="">
        <?php wp_nonce_field('mytheme_comment_nonce'); ?>
        <input type="hidden" name="mytheme_comment" value="1">

        <label for="comment_author">Name</label>
        <input type="text" id="comment_author" name="comment_author"
               placeholder="Your name" required>

        <label for="comment_message">Message</label>
        <textarea id="comment_message" name="comment_message"
                  rows="4" placeholder="Write your comment..." required></textarea>

        <button type="submit">Post Comment</button>
    </form>
</section>

<!-- ══════════════════════════════════════ -->
<!--         STORED COMMENTS              -->
<!-- ══════════════════════════════════════ -->
<section class="comments-list">
    <h2>📋 Stored Comments</h2>

    <?php
    $comments = mytheme_get_comments();
    if (empty($comments)): ?>
        <p class="no-comments">No comments yet. Be the first!</p>
    <?php else: ?>
        <?php foreach ($comments as $c): ?>
            <div class="comment-card">
                <div class="comment-meta">
                    <strong><?php echo esc_html($c->author); ?></strong>
                    <span><?php echo date('M j, Y  g:i A', strtotime($c->created_at)); ?></span>
                </div>
                <p><?php echo nl2br(esc_html($c->message)); ?></p>
            </div>
        <?php endforeach; ?>
    <?php endif; ?>
</section>

<?php get_footer(); ?>
