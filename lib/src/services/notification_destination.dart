int mainTabForNotificationType(String? type) {
  return type == 'results_ready' || type == 'order_accepted' ? 2 : 0;
}
