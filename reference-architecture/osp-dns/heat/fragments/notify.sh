# Send success status to OpenStack WaitCondition
function notify_success() {
    $WC_NOTIFY --insecure --data-binary \
               "{\"status\": \"SUCCESS\", \"reason\": \"$1\", \"data\": \"$1\"}"
    exit 0
}

# Send success status to OpenStack WaitCondition
function notify_failure() {
    $WC_NOTIFY --insecure --data-binary \
               "{\"status\": \"FAILURE\", \"reason\": \"$1\", \"data\": \"$1\"}"
    exit 1
}
