class ParkingRateConstants {
  // General Parking Rates
  static const dropAndGoTwoWheelerRates = [
    {'time': '0-10 Minutes', 'price': 'Free'},
    {'time': '10-20 Minutes', 'price': '₹20'},
    {'time': '20-30 Minutes', 'price': '₹40'},
    {'time': 'Beyond 30 Minutes (Till 24 hours)', 'price': '₹100'},
  ];

  static const dropAndGoFourWheelerRates = [
    {'time': '0-10 Minutes', 'price': 'Free'},
    {'time': '10-20 Minutes', 'price': '₹40'},
    {'time': '20-30 Minutes', 'price': '₹80'},
    {'time': 'Beyond 30 Minutes (Till 24 hours)', 'price': '₹200'},
  ];

  // Premium Parking Rates
  static const longParkingTwoWheelerRates = [
    {'time': '1 Day', 'price': '₹150'},
    {'time': '2 Days', 'price': '₹250'},
    {'time': '3 Days', 'price': '₹350'},
    {'time': 'Additional days', 'price': '₹100/day'},
  ];

  static const longParkingFourWheelerRates = [
    {'time': '1 Day', 'price': '₹300'},
    {'time': '2 Days', 'price': '₹500'},
    {'time': '3 Days', 'price': '₹700'},
    {'time': 'Additional days', 'price': '₹200/day'},
  ];
}
