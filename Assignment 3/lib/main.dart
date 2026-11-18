import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const WeatherApp());
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Weather App',
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
          secondary: Color(0xFF818CF8),
          surface: Color(0xFF1E293B),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F172A),
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: const MainNavigationPage(),
    );
  }
}

// ==================== WEATHER DATA MODELS ====================

class CurrentWeather {
  final String cityName;
  final String country;
  final double temp;
  final double feelsLike;
  final double tempMin;
  final double tempMax;
  final String condition;
  final String description;
  final String iconCode;
  final int humidity;
  final double windSpeed;
  final int pressure;
  final int visibility;
  final DateTime sunrise;
  final DateTime sunset;

  CurrentWeather({
    required this.cityName,
    required this.country,
    required this.temp,
    required this.feelsLike,
    required this.tempMin,
    required this.tempMax,
    required this.condition,
    required this.description,
    required this.iconCode,
    required this.humidity,
    required this.windSpeed,
    required this.pressure,
    required this.visibility,
    required this.sunrise,
    required this.sunset,
  });

  factory CurrentWeather.fromJson(Map<String, dynamic> json) {
    final main = json['main'] as Map<String, dynamic>? ?? {};
    final weatherList = json['weather'] as List<dynamic>? ?? [];
    final weatherFirst = weatherList.isNotEmpty
        ? (weatherList[0] as Map<String, dynamic>)
        : <String, dynamic>{};
    final wind = json['wind'] as Map<String, dynamic>? ?? {};
    final sys = json['sys'] as Map<String, dynamic>? ?? {};

    return CurrentWeather(
      cityName: json['name'] as String? ?? 'Unknown',
      country: sys['country'] as String? ?? '',
      temp: (main['temp'] as num?)?.toDouble() ?? 0.0,
      feelsLike: (main['feels_like'] as num?)?.toDouble() ?? 0.0,
      tempMin: (main['temp_min'] as num?)?.toDouble() ?? 0.0,
      tempMax: (main['temp_max'] as num?)?.toDouble() ?? 0.0,
      condition: weatherFirst['main'] as String? ?? 'Clear',
      description: weatherFirst['description'] as String? ?? 'Clear sky',
      iconCode: weatherFirst['icon'] as String? ?? '01d',
      humidity: (main['humidity'] as num?)?.toInt() ?? 0,
      windSpeed: (wind['speed'] as num?)?.toDouble() ?? 0.0,
      pressure: (main['pressure'] as num?)?.toInt() ?? 1013,
      visibility: (json['visibility'] as num?)?.toInt() ?? 10000,
      sunrise: DateTime.fromMillisecondsSinceEpoch(
        ((sys['sunrise'] as num?)?.toInt() ?? 0) * 1000,
      ),
      sunset: DateTime.fromMillisecondsSinceEpoch(
        ((sys['sunset'] as num?)?.toInt() ?? 0) * 1000,
      ),
    );
  }
}

class ForecastItem {
  final DateTime dateTime;
  final double temp;
  final double tempMin;
  final double tempMax;
  final String condition;
  final String description;
  final String iconCode;
  final int humidity;
  final double windSpeed;

  ForecastItem({
    required this.dateTime,
    required this.temp,
    required this.tempMin,
    required this.tempMax,
    required this.condition,
    required this.description,
    required this.iconCode,
    required this.humidity,
    required this.windSpeed,
  });

  factory ForecastItem.fromJson(Map<String, dynamic> json) {
    final main = json['main'] as Map<String, dynamic>? ?? {};
    final weatherList = json['weather'] as List<dynamic>? ?? [];
    final weatherFirst = weatherList.isNotEmpty
        ? (weatherList[0] as Map<String, dynamic>)
        : <String, dynamic>{};
    final wind = json['wind'] as Map<String, dynamic>? ?? {};

    return ForecastItem(
      dateTime: DateTime.fromMillisecondsSinceEpoch(
        ((json['dt'] as num?)?.toInt() ?? 0) * 1000,
      ),
      temp: (main['temp'] as num?)?.toDouble() ?? 0.0,
      tempMin: (main['temp_min'] as num?)?.toDouble() ?? 0.0,
      tempMax: (main['temp_max'] as num?)?.toDouble() ?? 0.0,
      condition: weatherFirst['main'] as String? ?? 'Clear',
      description: weatherFirst['description'] as String? ?? 'Clear sky',
      iconCode: weatherFirst['icon'] as String? ?? '01d',
      humidity: (main['humidity'] as num?)?.toInt() ?? 0,
      windSpeed: (wind['speed'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// ==================== MAIN NAVIGATION ====================

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 0;
  bool _isCelsius = true;

  // OpenWeatherMap API Key
  final String _apiKey = '1c5a1a82a81746071f043e3fafbe2f9c';

  CurrentWeather? _currentWeather;
  List<ForecastItem> _forecastList = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _activeCity = 'London';

  final List<String> _recentSearches = ['London', 'Tokyo', 'New York'];

  @override
  void initState() {
    super.initState();
    try {
      final uri = Uri.base;
      if (uri.queryParameters.containsKey('city')) {
        _activeCity = uri.queryParameters['city']!;
      }
      if (uri.queryParameters.containsKey('tab')) {
        _currentIndex = int.tryParse(uri.queryParameters['tab']!) ?? 0;
      }
      if (uri.queryParameters.containsKey('error')) {
        _activeCity = 'InvalidCity99_XYZ';
      }
    } catch (_) {}
    _fetchWeatherByCity(_activeCity);
  }

  double _convertTemp(double tempCelsius) {
    if (_isCelsius) return tempCelsius;
    return (tempCelsius * 9 / 5) + 32;
  }

  String _tempUnitString() => _isCelsius ? '°C' : '°F';

  Future<void> _fetchWeatherByCity(String cityName) async {
    final trimmed = cityName.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a city name.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final weatherUrl = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?q=$trimmed&appid=$_apiKey&units=metric',
      );
      final forecastUrl = Uri.parse(
        'https://api.openweathermap.org/data/2.5/forecast?q=$trimmed&appid=$_apiKey&units=metric',
      );

      final weatherResponse = await http.get(weatherUrl).timeout(
        const Duration(seconds: 12),
      );
      final forecastResponse = await http.get(forecastUrl).timeout(
        const Duration(seconds: 12),
      );

      if (weatherResponse.statusCode == 200) {
        final weatherJson = jsonDecode(weatherResponse.body);
        final weather = CurrentWeather.fromJson(weatherJson);

        List<ForecastItem> forecasts = [];
        if (forecastResponse.statusCode == 200) {
          final forecastJson = jsonDecode(forecastResponse.body);
          final list = forecastJson['list'] as List<dynamic>? ?? [];
          forecasts = list.map((item) => ForecastItem.fromJson(item)).toList();
        }

        setState(() {
          _currentWeather = weather;
          _forecastList = forecasts;
          _activeCity = weather.cityName;
          _isLoading = false;
          _errorMessage = '';
          if (!_recentSearches.contains(weather.cityName)) {
            _recentSearches.insert(0, weather.cityName);
            if (_recentSearches.length > 8) _recentSearches.removeLast();
          }
        });
      } else if (weatherResponse.statusCode == 404) {
        setState(() {
          _errorMessage =
              'City "$trimmed" not found. Please verify spelling and try again.';
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
              'Failed to retrieve weather data (Error ${weatherResponse.statusCode}).';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage =
            'Network error: Unable to connect to OpenWeatherMap. Please check your internet connection.';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchWeatherByCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _fetchWeatherByCity(_activeCity);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _fetchWeatherByCity(_activeCity);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _fetchWeatherByCity(_activeCity);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 5),
      );

      final url = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?lat=${position.latitude}&lon=${position.longitude}&appid=$_apiKey&units=metric',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final cityName = data['name'] as String? ?? 'London';
        await _fetchWeatherByCity(cityName);
      } else {
        await _fetchWeatherByCity(_activeCity);
      }
    } catch (_) {
      // Graceful fallback to default/active city on devices without GPS
      await _fetchWeatherByCity(_activeCity);
    }
  }

  LinearGradient _getWeatherGradient(String condition) {
    switch (condition.toLowerCase()) {
      case 'clear':
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0284C7), Color(0xFF0369A1), Color(0xFF0F172A)],
        );
      case 'rain':
      case 'drizzle':
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E293B), Color(0xFF0F172A), Color(0xFF020617)],
        );
      case 'thunderstorm':
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4C1D95), Color(0xFF1E1B4B), Color(0xFF0F172A)],
        );
      case 'snow':
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0E7490), Color(0xFF155E75), Color(0xFF0F172A)],
        );
      case 'clouds':
      default:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E293B), Color(0xFF334155), Color(0xFF0F172A)],
        );
    }
  }

  IconData _getWeatherIcon(String condition) {
    switch (condition.toLowerCase()) {
      case 'clear':
        return Icons.wb_sunny_rounded;
      case 'clouds':
        return Icons.cloud_rounded;
      case 'rain':
        return Icons.water_drop_rounded;
      case 'drizzle':
        return Icons.grain_rounded;
      case 'thunderstorm':
        return Icons.flash_on_rounded;
      case 'snow':
        return Icons.ac_unit_rounded;
      case 'mist':
      case 'fog':
        return Icons.blur_on_rounded;
      default:
        return Icons.wb_cloudy_rounded;
    }
  }

  Color _getIconColor(String condition) {
    switch (condition.toLowerCase()) {
      case 'clear':
        return const Color(0xFFFBBF24);
      case 'clouds':
        return const Color(0xFF94A3B8);
      case 'rain':
      case 'drizzle':
        return const Color(0xFF38BDF8);
      case 'thunderstorm':
        return const Color(0xFFA855F7);
      case 'snow':
        return const Color(0xFF67E8F9);
      default:
        return const Color(0xFF38BDF8);
    }
  }

  // ==================== SCREEN 1: WEATHER HOME ====================

  Widget _buildHomeScreen() {
    final weather = _currentWeather;
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF38BDF8)),
            SizedBox(height: 18),
            Text(
              'Fetching Live Weather...',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_errorMessage.isNotEmpty && weather == null) {
      return _buildErrorScreen();
    }

    if (weather == null) {
      return const Center(
        child: Text(
          'No weather data available',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF38BDF8),
      onRefresh: () => _fetchWeatherByCity(_activeCity),
      child: Container(
        decoration: BoxDecoration(
          gradient: _getWeatherGradient(weather.condition),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Quick Search Bar at top of Home
                _buildQuickSearchBar(),
                const SizedBox(height: 16),

                if (_errorMessage.isNotEmpty) _buildErrorBanner(),

                // City Name & Date
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: Color(0xFF38BDF8),
                      size: 26,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${weather.cityName}, ${weather.country}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(DateTime.now()),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white60,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 20),

                // Hero Weather Visual & Temperature
                _buildHeroCard(weather),
                const SizedBox(height: 24),

                // Key Weather Details Grid
                _buildDetailsSection(weather),
                const SizedBox(height: 24),

                // Hourly / 24-hr Forecast Horizontal List
                _buildHourlySection(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickSearchBar() {
    final controller = TextEditingController();
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x331E293B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search any city worldwide...',
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF38BDF8)),
          suffixIcon: IconButton(
            icon: const Icon(Icons.my_location, color: Colors.white60),
            tooltip: 'Current Location',
            onPressed: _fetchWeatherByCurrentLocation,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) {
            _fetchWeatherByCity(value.trim());
          }
        },
      ),
    );
  }

  Widget _buildHeroCard(CurrentWeather weather) {
    final tempVal = _convertTemp(weather.temp).round();
    final feelsLikeVal = _convertTemp(weather.feelsLike).round();
    final minVal = _convertTemp(weather.tempMin).round();
    final maxVal = _convertTemp(weather.tempMax).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0x33000000),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Weather Icon (Both Network image and fallback Icon)
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _getIconColor(weather.condition).withOpacity(0.15),
                ),
              ),
              Image.network(
                'https://openweathermap.org/img/wn/${weather.iconCode}@4x.png',
                width: 110,
                height: 110,
                errorBuilder: (context, error, stackTrace) => Icon(
                  _getWeatherIcon(weather.condition),
                  size: 72,
                  color: _getIconColor(weather.condition),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Big Temperature
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$tempVal',
                style: const TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.w200,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
              Text(
                _tempUnitString(),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF38BDF8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Condition Title
          Text(
            weather.description.toUpperCase(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),

          // Feels like and Min / Max
          Text(
            'Feels like $feelsLikeVal${_tempUnitString()} • H: $maxVal°  L: $minVal°',
            style: const TextStyle(fontSize: 14, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection(CurrentWeather weather) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            'Weather Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.6,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _buildDetailCard(
              title: 'Humidity',
              value: '${weather.humidity}%',
              icon: Icons.water_drop_outlined,
              accentColor: const Color(0xFF38BDF8),
            ),
            _buildDetailCard(
              title: 'Wind Speed',
              value: '${weather.windSpeed.toStringAsFixed(1)} m/s',
              icon: Icons.air_rounded,
              accentColor: const Color(0xFF34D399),
            ),
            _buildDetailCard(
              title: 'Pressure',
              value: '${weather.pressure} hPa',
              icon: Icons.compress_rounded,
              accentColor: const Color(0xFFF472B6),
            ),
            _buildDetailCard(
              title: 'Visibility',
              value: '${(weather.visibility / 1000).toStringAsFixed(1)} km',
              icon: Icons.visibility_rounded,
              accentColor: const Color(0xFFFBBF24),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accentColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlySection() {
    if (_forecastList.isEmpty) return const SizedBox.shrink();

    final hourlyItems = _forecastList.take(8).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            'Next 24 Hours',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        SizedBox(
          height: 130,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: hourlyItems.length,
            itemBuilder: (context, index) {
              final item = hourlyItems[index];
              final temp = _convertTemp(item.temp).round();
              final timeStr = _formatTime(item.dateTime);

              return Container(
                width: 90,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                    Image.network(
                      'https://openweathermap.org/img/wn/${item.iconCode}.png',
                      width: 40,
                      height: 40,
                      errorBuilder: (_, __, ___) => Icon(
                        _getWeatherIcon(item.condition),
                        size: 24,
                        color: _getIconColor(item.condition),
                      ),
                    ),
                    Text(
                      '$temp°',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ==================== SCREEN 2: 5-DAY FORECAST ====================

  Widget _buildForecastScreen() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF38BDF8)),
            SizedBox(height: 18),
            Text(
              'Loading 5-Day Forecast...',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_forecastList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 64, color: Colors.white30),
            const SizedBox(height: 16),
            const Text(
              'No forecast data loaded yet.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _fetchWeatherByCity(_activeCity),
              child: const Text('Refresh Forecast'),
            ),
          ],
        ),
      );
    }

    // Group 3-hour forecasts by Day
    final Map<String, List<ForecastItem>> grouped = {};
    for (var f in _forecastList) {
      final key = _formatDayOfWeek(f.dateTime);
      grouped.putIfAbsent(key, () => []).add(f);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('5-Day Forecast (${_activeCity})'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header summary card
            Container(
              padding: const EdgeInsets.all(18),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0284C7), Color(0xFF0F172A)],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    color: Color(0xFF38BDF8),
                    size: 36,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Upcoming Weather for ${_activeCity}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Detailed 5-day / 3-hour forecast updates',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            ...grouped.entries.map((entry) {
              final dayName = entry.key;
              final dayList = entry.value;

              double maxT = -999;
              double minT = 999;
              String topCondition = dayList.first.condition;
              String topIcon = dayList.first.iconCode;

              for (var it in dayList) {
                if (it.tempMax > maxT) maxT = it.tempMax;
                if (it.tempMin < minT) minT = it.tempMin;
              }

              final maxFormatted = _convertTemp(maxT).round();
              final minFormatted = _convertTemp(minT).round();

              return Card(
                color: const Color(0xFF1E293B).withOpacity(0.7),
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Colors.white10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 70,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          dayName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Image.network(
                        'https://openweathermap.org/img/wn/$topIcon.png',
                        width: 44,
                        height: 44,
                        errorBuilder: (_, __, ___) => Icon(
                          _getWeatherIcon(topCondition),
                          color: _getIconColor(topCondition),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          topCondition,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            '$maxFormatted°',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$minFormatted°',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ==================== SCREEN 3: SEARCH CITY ====================

  Widget _buildSearchScreen() {
    final searchController = TextEditingController();
    final popularCities = [
      'London',
      'New York',
      'Tokyo',
      'Paris',
      'Dubai',
      'Sydney',
      'Singapore',
      'Cairo',
      'Berlin',
      'Toronto',
      'Lahore',
      'Karachi',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search & Explore Cities'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Input Field
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: TextField(
                  controller: searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Enter city name (e.g. Paris, Tokyo)...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF38BDF8),
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Color(0xFF38BDF8),
                      ),
                      onPressed: () {
                        if (searchController.text.trim().isNotEmpty) {
                          _handleCitySelected(searchController.text.trim());
                        }
                      },
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty) {
                      _handleCitySelected(value.trim());
                    }
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Search Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    if (searchController.text.trim().isNotEmpty) {
                      _handleCitySelected(searchController.text.trim());
                    }
                  },
                  icon: const Icon(Icons.search),
                  label: const Text(
                    'Search Weather',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildErrorBanner(),
              ],

              const SizedBox(height: 32),

              // Recent Searches
              if (_recentSearches.isNotEmpty) ...[
                const Text(
                  'Recent Searches',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _recentSearches.map((city) {
                    return ActionChip(
                      avatar: const Icon(
                        Icons.history,
                        size: 16,
                        color: Color(0xFF38BDF8),
                      ),
                      label: Text(city),
                      backgroundColor: const Color(0xFF1E293B),
                      side: const BorderSide(color: Colors.white12),
                      labelStyle: const TextStyle(color: Colors.white),
                      onPressed: () => _handleCitySelected(city),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),
              ],

              // Popular Cities Chips
              const Text(
                'Popular World Cities',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: popularCities.map((city) {
                  return ActionChip(
                    avatar: const Icon(
                      Icons.location_city,
                      size: 16,
                      color: Color(0xFF818CF8),
                    ),
                    label: Text(city),
                    backgroundColor: const Color(0xFF1E293B),
                    side: const BorderSide(color: Colors.white12),
                    labelStyle: const TextStyle(color: Colors.white),
                    onPressed: () => _handleCitySelected(city),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleCitySelected(String city) {
    setState(() {
      _currentIndex = 0;
    });
    _fetchWeatherByCity(city);
  }

  // ==================== ERROR HANDLING SCREENS ====================

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF7F1D1D).withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 18),
            onPressed: () => setState(() => _errorMessage = ''),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 64,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Weather Connection Error',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () => _fetchWeatherByCity(_activeCity),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry Connection'),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== HELPER FORMATTERS ====================

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final dayName = weekdays[dt.weekday - 1];
    final monthName = months[dt.month - 1];
    return '$dayName, $monthName ${dt.day}';
  }

  String _formatDayOfWeek(DateTime dt) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[dt.weekday - 1];
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour;
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour % 12 == 0 ? 12 : hour % 12;
    return '$h $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Live Weather App',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          // °C / °F Unit Switcher
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ActionChip(
              backgroundColor: const Color(0xFF1E293B),
              side: const BorderSide(color: Color(0xFF38BDF8)),
              label: Text(
                _isCelsius ? '°C' : '°F',
                style: const TextStyle(
                  color: Color(0xFF38BDF8),
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                setState(() {
                  _isCelsius = !_isCelsius;
                });
              },
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeScreen(),
          _buildForecastScreen(),
          _buildSearchScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        backgroundColor: const Color(0xFF0F172A),
        selectedItemColor: const Color(0xFF38BDF8),
        unselectedItemColor: Colors.white38,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.wb_sunny_outlined),
            activeIcon: Icon(Icons.wb_sunny),
            label: 'Current',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: '5-Day Forecast',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search_rounded),
            activeIcon: Icon(Icons.search),
            label: 'Search Cities',
          ),
        ],
      ),
    );
  }
}
