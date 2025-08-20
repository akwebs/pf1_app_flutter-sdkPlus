class LoaderController {
  bool loading;

  LoaderController({required this.loading});

  void showLoading() {
    loading = true;
  }

  void hideLoading() {
    loading = false;
  }
}
