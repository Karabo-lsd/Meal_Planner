# ML Pipeline Design

## Overview

The ML pipeline implements an ensemble approach for food recognition using state-of-the-art computer vision models. The system is designed for production deployment with MLOps best practices.

## Model Architecture

### Food Classification Ensemble

**Primary Models:**
- **ResNet-50**: Pre-trained on ImageNet, fine-tuned on food datasets
- **EfficientNet-B3**: Lightweight model optimized for mobile deployment

**Ensemble Strategy:**
- Weighted voting based on confidence scores
- Confidence thresholding (minimum 0.3)
- Fallback to manual entry for low-confidence predictions

### Portion Estimation

**Model:** U-Net architecture for semantic segmentation
- **Input:** Food image with detected bounding boxes
- **Output:** Pixel-wise segmentation masks
- **Post-processing:** Volume estimation using reference objects

### Nutritional Mapping

**Database Integration:**
- USDA FoodData Central API
- Custom nutritional database
- Confidence-weighted nutritional calculation

## Training Pipeline

### Data Sources

1. **USDA FoodData Central**: 200,000+ food items with nutritional data
2. **Food-101**: 101,000 images across 101 food categories
3. **Recipe1M**: 1M+ recipes with ingredient lists
4. **Custom Dataset**: User-generated images with corrections

### Data Preprocessing

```python
def preprocess_image(image):
    # Resize to 224x224
    image = cv2.resize(image, (224, 224))

    # Normalize
    image = image / 255.0
    mean = np.array([0.485, 0.456, 0.406])
    std = np.array([0.229, 0.224, 0.225])
    image = (image - mean) / std

    return image
```

### Training Configuration

```python
training_config = {
    'batch_size': 32,
    'learning_rate': 1e-4,
    'epochs': 100,
    'optimizer': 'Adam',
    'loss_function': 'CrossEntropyLoss',
    'scheduler': 'StepLR'
}
```

### Model Training

**ResNet-50 Fine-tuning:**
```python
model = models.resnet50(pretrained=True)
# Freeze early layers
for param in model.parameters():
    param.requires_grad = False

# Replace classifier
model.fc = nn.Linear(2048, num_classes)
```

**EfficientNet-B3:**
```python
model = EfficientNet.from_pretrained('efficientnet-b3')
model._fc = nn.Linear(model._fc.in_features, num_classes)
```

## MLOps Pipeline

### Experiment Tracking

Using MLflow for experiment management:

```python
import mlflow
import mlflow.pytorch

with mlflow.start_run():
    mlflow.log_params(training_config)
    mlflow.log_metrics({'accuracy': accuracy, 'loss': loss})
    mlflow.pytorch.log_model(model, 'model')
```

### Model Registry

```python
# Register model
model_uri = f"runs:/{run_id}/model"
mlflow.register_model(model_uri, "FoodClassifier")

# Transition to production
client = mlflow.tracking.MlflowClient()
client.transition_model_version_stage(
    name="FoodClassifier",
    version=1,
    stage="Production"
)
```

### Automated Retraining

**Trigger Conditions:**
- User correction rate > 5%
- Model drift detected (>10% accuracy drop)
- New data available (weekly batch)

**Retraining Pipeline:**
1. Collect new training data
2. Validate data quality
3. Retrain ensemble models
4. A/B test against current production model
5. Deploy winner to production

## Inference Pipeline

### Model Serving

**ONNX Optimization:**
```python
# Convert to ONNX
torch.onnx.export(
    model,
    dummy_input,
    "food_classifier.onnx",
    opset_version=11,
    input_names=['input'],
    output_names=['output']
)

# Load ONNX model
import onnxruntime as ort
session = ort.InferenceSession("food_classifier.onnx")
```

**Batch Inference:**
```python
def predict_batch(images):
    # Preprocess batch
    processed_images = [preprocess_image(img) for img in images]
    batch = np.stack(processed_images)

    # Run inference
    outputs = session.run(None, {'input': batch})

    # Post-process
    predictions = postprocess_outputs(outputs)
    return predictions
```

### Performance Optimization

**Techniques:**
- Model quantization (INT8)
- TensorRT optimization
- GPU acceleration
- Request batching

**Target Performance:**
- P95 latency: <500ms
- Throughput: 100 requests/second
- Accuracy: >90% top-5

## A/B Testing Framework

### Test Configuration

```python
ab_test_config = {
    'test_name': 'model_v2_vs_v1',
    'variants': {
        'control': 'FoodClassifier-v1',
        'treatment': 'FoodClassifier-v2'
    },
    'traffic_split': [50, 50],
    'metrics': ['accuracy', 'user_satisfaction', 'processing_time'],
    'duration_days': 14
}
```

### Metrics Collection

```python
def log_prediction(user_id, variant, prediction, ground_truth):
    analytics.track('food_recognition', {
        'user_id': user_id,
        'variant': variant,
        'prediction': prediction,
        'ground_truth': ground_truth,
        'correct': prediction == ground_truth
    })
```

### Statistical Analysis

```python
from scipy import stats

def analyze_ab_test(results):
    control_accuracy = results[results.variant == 'control'].accuracy
    treatment_accuracy = results[results.variant == 'treatment'].accuracy

    # T-test for statistical significance
    t_stat, p_value = stats.ttest_ind(control_accuracy, treatment_accuracy)

    return {
        't_statistic': t_stat,
        'p_value': p_value,
        'significant': p_value < 0.05
    }
```

## Model Monitoring

### Drift Detection

**Techniques:**
- Population stability index (PSI)
- Kolmogorov-Smirnov test
- Chi-square test for categorical drift

```python
def detect_drift(reference_data, current_data):
    psi = calculate_psi(reference_data, current_data)
    if psi > 0.1:  # Significant drift
        alert_drift()
```

### Performance Monitoring

**Key Metrics:**
- Model accuracy over time
- Prediction confidence distribution
- User correction rate
- Inference latency percentiles

### Alerting

```yaml
alerts:
  - name: model_accuracy_drop
    condition: accuracy < 0.85
    severity: critical

  - name: high_latency
    condition: p95_latency > 1000ms
    severity: warning

  - name: high_correction_rate
    condition: correction_rate > 0.1
    severity: warning
```

## Data Pipeline

### Data Collection

**Sources:**
- User-uploaded images
- User corrections and feedback
- External food databases
- Web scraping (with permission)

### Data Validation

```python
def validate_food_image(image, metadata):
    # Check image quality
    if image.size < 10000:  # Too small
        return False

    # Check for food content (basic heuristic)
    if not contains_food(image):
        return False

    # Validate metadata
    required_fields = ['meal_type', 'user_id']
    if not all(field in metadata for field in required_fields):
        return False

    return True
```

### Data Labeling

**Semi-supervised Approach:**
1. Model predictions as initial labels
2. User corrections to improve labels
3. Active learning for uncertain samples

## Deployment Strategy

### Model Versioning

```python
model_versions = {
    'v1.0.0': {
        'models': ['resnet50_v1', 'efficientnet_v1'],
        'weights': [0.6, 0.4],
        'accuracy': 0.92
    },
    'v2.0.0': {
        'models': ['resnet50_v2', 'efficientnet_v2'],
        'weights': [0.5, 0.5],
        'accuracy': 0.94
    }
}
```

### Rollback Strategy

- Keep last 3 model versions
- Automatic rollback on accuracy drop >5%
- Gradual rollout with canary deployment

### Scaling

**Horizontal Scaling:**
- Multiple inference pods
- Load balancer distribution
- Auto-scaling based on queue depth

**Resource Optimization:**
- GPU utilization monitoring
- Model caching for frequent requests
- Batch processing for efficiency

## Security Considerations

### Model Security

- Input validation and sanitization
- Adversarial input detection
- Model watermarking
- Access control for model endpoints

### Data Privacy

- Image anonymization before training
- Federated learning consideration
- Data retention policies
- GDPR compliance for user data

## Future Improvements

### Advanced Techniques

1. **Multi-modal Models**: Combine vision with text (recipe titles, ingredients)
2. **Few-shot Learning**: Adapt to new foods with minimal examples
3. **Self-supervised Learning**: Unsupervised pre-training on large datasets
4. **Transformer Models**: Vision transformers for better accuracy

### Edge Deployment

- TensorFlow Lite models for mobile
- On-device inference for privacy
- Hybrid cloud-edge architecture

### Explainability

- SHAP values for prediction explanations
- Attention visualization
- User feedback integration