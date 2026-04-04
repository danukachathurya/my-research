# Vehicle Troubleshooting Chatbot - NLP Preprocessing

## Overview
This directory contains the NLP preprocessing pipeline for the vehicle troubleshooting chatbot supporting Toyota Aqua, Prius, Corolla, Suzuki Alto, and Toyota Vitz vehicles in Sri Lanka.

## Files Created

### 1. `nlp_preprocessing.ipynb`
Comprehensive Jupyter notebook containing:
- **Data Loading & Exploration**: Load and analyze both datasets
- **Text Preprocessing**: Clean, tokenize, lemmatize text
- **Visualization**: Word clouds, frequency analysis, distribution plots
- **TF-IDF Vectorization**: Create semantic search vectors
- **Similarity Testing**: Test query matching against datasets
- **Export**: Save processed data and models

### 2. `text_preprocessor.py`
Standalone Python module with reusable preprocessing classes:
- `TextPreprocessor`: Core text preprocessing for English and Sinhala
- `DatasetPreprocessor`: Batch processing for DataFrames
- `detect_language()`: Automatic language detection

### 3. `requirements.txt`
All Python dependencies needed for the project

## Dataset Structure

### Main Dataset: `sri_lanka_vehicle_dataset_5models_englishonly.xlsx`
- **Records**: 250 vehicle issues
- **Columns**:
  - `id`: Unique identifier
  - `make`: Vehicle manufacturer
  - `model`: Vehicle model (Aqua, Prius, Corolla, Alto, Vitz)
  - `powertrain`: Engine type (Hybrid, Petrol, etc.)
  - `quick_checks`: Immediate diagnostic steps
  - `diagnostic_steps`: Detailed troubleshooting
  - `recommended_actions`: Solutions
  - `sri_lanka_notes`: Local context
  - `safety_note`: Safety warnings

### Fallback Dataset: `fallback_dataset.xlsx`
- **Records**: 250 fallback scenarios
- **Columns**:
  - `id`: Unique identifier
  - `intent`: User intent category
  - `user_example`: Sample user queries
  - `bot_reply`: Generic bot responses
  - `bot_questions`: Diagnostic questions to ask
  - `generic_quick_checks`: Universal checks
  - `safety_rules`: Safety guidelines
  - `next_step`: Follow-up actions

## Getting Started

### Step 1: Install Dependencies
```bash
cd "e:\research\gamage new\data"
pip install -r requirements.txt
```

### Step 2: Run the Preprocessing Notebook
```bash
jupyter notebook nlp_preprocessing.ipynb
```

Execute all cells to:
1. Load and explore datasets
2. Preprocess text data
3. Generate visualizations
4. Create TF-IDF vectors
5. Export processed files

### Step 3: Use the Preprocessor Module
```python
from text_preprocessor import TextPreprocessor, DatasetPreprocessor

# For English text
preprocessor = TextPreprocessor(language='english')
cleaned_text = preprocessor.preprocess_pipeline("My car won't start!")

# For Sinhala text
preprocessor_si = TextPreprocessor(language='sinhala')
cleaned_text_si = preprocessor_si.preprocess_pipeline("මගේ කාරය ස්ටාර්ට් වෙන්නේ නැහැ")

# For batch processing
dataset_processor = DatasetPreprocessor(language='english')
df_processed = dataset_processor.preprocess_dataframe(
    df,
    text_columns=['quick_checks', 'diagnostic_steps']
)
```

## Output Files (After Running Notebook)

1. **main_dataset_processed.csv**: Preprocessed main dataset
2. **fallback_dataset_processed.csv**: Preprocessed fallback dataset
3. **tfidf_vectorizer_main.pkl**: TF-IDF model for main dataset
4. **tfidf_vectorizer_fallback.pkl**: TF-IDF model for fallback dataset
5. **tfidf_matrix_main.npz**: Sparse matrix for semantic search
6. **tfidf_matrix_fallback.npz**: Sparse matrix for fallback matching

## Key Features

### Multilingual Support
- **English**: Full NLP pipeline (lemmatization, stopword removal)
- **Sinhala**: Unicode-aware cleaning and tokenization

### Text Preprocessing Pipeline
1. **Cleaning**: Remove URLs, emails, special characters
2. **Normalization**: Lowercase conversion, contraction expansion
3. **Tokenization**: Word-level tokenization
4. **Stopword Removal**: Language-aware (preserves automotive keywords)
5. **Lemmatization**: Convert words to base form
6. **Vectorization**: TF-IDF for semantic search

### Automotive Domain Optimization
Protected keywords that are NOT removed as stopwords:
- engine, start, brake, battery, oil, fuel, check
- light, warning, noise, smell, leak, hot, cold
- ac, air, power, speed, wheel, tire, steering
- pump, filter, belt, hose, coolant, transmission

## Preprocessing Examples

### Before Preprocessing:
```
"My car's engine won't start! There's a strange clicking noise and the battery light is on."
```

### After Preprocessing:
```
"car engine start strange clicking noise battery light"
```

### Sinhala Example:
**Before**: `"මගේ මෝටර් රථයේ එන්ජින් එක ස්ටාර්ට් වෙන්නේ නැහැ"`
**After**: `"මෝටර රථයේ එන්ජින එක ස්ටාර්ට වෙන්නේ"`

## Semantic Search Testing

The notebook includes similarity search functionality:
```python
query = "My engine won't start"
results = find_similar_issues(query, main_df, tfidf_vectorizer, tfidf_matrix, top_n=5)
```

This returns the top 5 most similar issues from the dataset based on TF-IDF cosine similarity.

## Next Steps

After completing NLP preprocessing:

1. **Gemini API Integration**:
   - Create `gemini_integration.ipynb`
   - Use Gemini embeddings for better semantic search
   - Implement Gemini Pro for conversational responses

2. **Chatbot Development**:
   - Build main chatbot logic
   - Implement intent classification
   - Add conversation state management

3. **Fallback System**:
   - Implement diagnostic question flow
   - Create context-aware responses
   - Add vehicle model detection

4. **Warning Light Recognition**:
   - Integrate Gemini Vision API
   - Build dashboard image classifier
   - Add severity assessment

5. **Voice Integration**:
   - Add speech-to-text (Google Speech API)
   - Implement text-to-speech
   - Support Sinhala voice input/output

## Troubleshooting

### NLTK Data Not Found
```python
import nltk
nltk.download('punkt')
nltk.download('stopwords')
nltk.download('wordnet')
```

### Encoding Issues with Sinhala
Ensure your files use UTF-8 encoding:
```python
df = pd.read_csv('file.csv', encoding='utf-8')
```

## Project Structure
```
e:\research\gamage new\data\
├── sri_lanka_vehicle_dataset_5models_englishonly.xlsx  # Original main dataset
├── fallback_dataset.xlsx                               # Original fallback dataset
├── nlp_preprocessing.ipynb                             # Main preprocessing notebook
├── text_preprocessor.py                                # Reusable preprocessing module
├── requirements.txt                                     # Python dependencies
├── README_NLP.md                                       # This file
├── main_dataset_processed.csv                          # (Generated)
├── fallback_dataset_processed.csv                      # (Generated)
├── tfidf_vectorizer_main.pkl                           # (Generated)
├── tfidf_vectorizer_fallback.pkl                       # (Generated)
├── tfidf_matrix_main.npz                               # (Generated)
└── tfidf_matrix_fallback.npz                           # (Generated)
```

## Contact & Support
For issues or questions about the NLP preprocessing pipeline, refer to the main project documentation.

---
**Last Updated**: December 2025
**Python Version**: 3.11+
**Supported Languages**: English, Sinhala
