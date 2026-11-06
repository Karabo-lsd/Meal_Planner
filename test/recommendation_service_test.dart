import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meal_planning_app/core/models/recipe.dart';
import 'package:meal_planning_app/core/providers.dart';
import 'package:meal_planning_app/services/recommendation_service.dart';

class _RecommendationAdapter implements HttpClientAdapter {
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode({
        'source': 'openai',
        'recommendations': [
          {
            'recipe_id': 'recipe-uuid',
            'score': 0.94,
            'reason': 'Matches the requested meal.',
            'recipe': {
              'id': 'recipe-uuid',
              'title': 'Chicken rice bowl',
              'source_provider': 'spoonacular',
              'calories': 460,
              'protein': 38.5,
              'carbs': 42.0,
              'fat': 13.2,
              'ingredients': ['chicken', 'rice'],
              'image_url': 'https://example.test/recipe.jpg',
            },
          },
        ],
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'backend recommendations map into recipes with nutrition intact',
    () async {
      final adapter = _RecommendationAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'http://meal-planner.test'));
      dio.httpClientAdapter = adapter;

      final recommendations = await RecommendationService(
        dio: dio,
      ).recommend(userId: 'user-1', requestType: 'dinner', limit: 3);

      expect(adapter.request?.path, '/api/recommendations');
      expect(adapter.request?.method, 'POST');
      expect(recommendations, hasLength(1));

      final recipe = Recipe.fromJson(
        Map<String, dynamic>.from(recommendations.single['recipe'] as Map),
      );
      expect(recipe.title, 'Chicken rice bowl');
      expect(recipe.sourceProvider, 'spoonacular');
      expect(recipe.calories, 460);
      expect(recipe.protein, 38.5);
      expect(recipe.carbs, 42.0);
      expect(recipe.fat, 13.2);
    },
  );

  test('recommendations provider exposes backend recipes to the app', () async {
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue('user-1'),
        recommendationServiceProvider.overrideWithValue(
          _FakeRecommendationService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final recipes = await container.read(recommendationsProvider.future);

    expect(recipes, hasLength(1));
    expect(recipes.single.title, 'Chicken rice bowl');
    expect(recipes.single.calories, 460);
    expect(recipes.single.protein, 38.5);
  });
}

class _FakeRecommendationService extends RecommendationService {
  _FakeRecommendationService() : super(dio: Dio());

  @override
  Future<List<Map<String, dynamic>>> recommend({
    required String userId,
    String requestType = 'dinner',
    String? query,
    int limit = 3,
    int page = 0,
    Map<String, dynamic> context = const {},
  }) async => [
    {
      'recipe_id': 'recipe-uuid',
      'score': 0.94,
      'reason': 'Matches the requested meal.',
      'recipe': {
        'id': 'recipe-uuid',
        'title': 'Chicken rice bowl',
        'source_provider': 'spoonacular',
        'calories': 460,
        'protein': 38.5,
        'carbs': 42.0,
        'fat': 13.2,
      },
    },
  ];
}
