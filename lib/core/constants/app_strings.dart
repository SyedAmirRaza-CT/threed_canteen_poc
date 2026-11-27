/// Every UI string lives here (no hardcoded text in widgets).
class AppStrings {
  AppStrings._();

  // Gate
  static const welcomeTitle = 'Welcome to the Canteen';
  static const welcomeSubtitle =
      'Fresh food, drinks and snacks. Step inside and pick what you like.';
  static const enterStore = 'Enter Store';
  static const entering = 'Opening the gate…';

  // HUD
  static const hintWalk = 'Left thumb: move · Right thumb: look · Pinch: zoom';
  static const nowViewing = 'Now viewing';
  static const basket = 'Basket';

  // Product sheet
  static const addToBasket = 'Add to basket';
  static const outOfStock = 'Out of stock';
  static const allInBasket = 'All stock is in your basket';
  static const calories = 'Calories';
  static const inStock = 'In stock';
  static const ingredients = 'Ingredients';
  static const veg = 'Veg';
  static const nonVeg = 'Non-veg';
  static const inYourBasket = 'In your basket';
  static const quantity = 'Quantity';

  // Basket
  static const yourBasket = 'Your basket';
  static const basketEmpty = 'Your basket is empty';
  static const basketEmptyHint =
      'Walk around and tap items on the shelves to add them.';
  static const items = 'Items';
  static const subtotal = 'Subtotal';
  static const tax = 'Tax (5%)';
  static const total = 'Total';
  static const totalCalories = 'Total calories';
  static const checkout = 'Checkout';
  static const clearBasket = 'Clear';
  static const continueShopping = 'Continue shopping';

  // Order
  static const placingOrder = 'Placing your order…';
  static const orderPlaced = 'Order placed!';
  static const orderNumber = 'Order number';
  static const orderThanks = 'Thank you. Your food will be ready shortly.';
  static const done = 'Done';

  // Errors / loading
  static const loadFailed = 'Could not load the store.';
  static const tryAgain = 'Try again';
  static const loadingStore = 'Setting up the store…';
}
