# 📓 NLP Preprocessing Notebook Guide

## ✅ Fixed Issues

Your notebook has been updated with:

1. **✅ Fixed NLTK Downloads**
   - Added SSL certificate handling
   - Better error messages
   - Downloads punkt, stopwords, wordnet, etc.

2. **✅ Fixed File Paths**
   - Updated to use `data/` folder
   - Works with new project structure

3. **✅ Ready to Run**
   - All cells should work without errors

---

## 🚀 How to Use the Notebook

### 1. Start Jupyter Notebook

```cmd
cd "e:\research\gamage new\data"
jupyter notebook
```

This will open in your browser.

### 2. Open the Notebook

Navigate to and open: `nlp_preprocessing.ipynb`

### 3. Run All Cells

Click: **Cell → Run All**

Or press **Shift + Enter** for each cell.

---

## 📋 What the Notebook Does

### Section 1-2: Setup
- Imports libraries
- Downloads NLTK data (punkt, stopwords, etc.)

### Section 3-4: Load Data
- Loads main dataset (250+ vehicle issues)
- Loads fallback dataset (250 scenarios)
- Shows data statistics

### Section 5-6: Preprocessing
- Creates `TextPreprocessor` class
- Tests preprocessing on sample texts
- Supports English and Sinhala

### Section 7-8: Process Datasets
- Cleans all text columns
- Removes stopwords
- Lemmatizes text
- Creates combined text fields

### Section 9: Analysis
- Word frequency analysis
- Generates word clouds
- Top 30 most common words

### Section 10-11: TF-IDF
- Creates TF-IDF vectors
- Tests semantic similarity
- Finds similar issues

### Section 12: Export
- Saves processed datasets
- Saves TF-IDF vectorizers
- Saves TF-IDF matrices

---

## 📁 Output Files

After running the notebook, you'll get:

```
data/
├── main_dataset_processed.csv          # Processed main dataset
├── fallback_dataset_processed.csv      # Processed fallback dataset
├── tfidf_vectorizer_main.pkl          # TF-IDF model for main data
├── tfidf_vectorizer_fallback.pkl      # TF-IDF model for fallback
├── tfidf_matrix_main.npz              # TF-IDF vectors (main)
└── tfidf_matrix_fallback.npz          # TF-IDF vectors (fallback)
```

These files are used by the chatbot for semantic search!

---

## 🔧 TextPreprocessor Features

The notebook includes a complete preprocessing class:

```python
preprocessor = TextPreprocessor(language='english')

# Available methods:
text = preprocessor.clean_text(text)                    # Basic cleaning
text = preprocessor.remove_stopwords(text)              # Remove stop words
text = preprocessor.lemmatize_text(text)                # Lemmatization
text = preprocessor.stem_text(text)                     # Stemming
text = preprocessor.expand_contractions(text)           # won't → will not
text = preprocessor.preprocess_pipeline(text)           # Complete pipeline
```

---

## 📊 What You'll See

### Word Clouds
Beautiful visualizations showing most common words in:
- Main dataset (vehicle issues)
- Fallback dataset (diagnostic questions)

### Statistics
- Vehicle model distribution
- Powertrain type breakdown
- Intent distribution
- Word frequency charts

### Similarity Search
Test queries like:
- "My car engine won't start"
- "Brake pedal feels soft"
- "Battery keeps dying"

See which dataset entries match best!

---

## 🐛 Troubleshooting

### Error: "Module not found"
```cmd
pip install pandas numpy nltk matplotlib seaborn wordcloud scikit-learn google-generativeai
```

### Error: "File not found"
Make sure you're in the project root:
```cmd
cd "e:\research\gamage new\data"
```

### Error: "NLTK data not found"
The notebook now downloads it automatically!
If it still fails, manually download:
```python
import nltk
nltk.download('punkt')
nltk.download('stopwords')
nltk.download('wordnet')
```

### Error: "Excel file not found"
Check that files exist in `data/` folder:
- `data/sri_lanka_vehicle_dataset_5models_englishonly.xlsx`
- `data/fallback_dataset.xlsx`

---

## 💡 Tips

### 1. Run Cells in Order
Always run from top to bottom first time.

### 2. Save Often
Click **File → Save** regularly.

### 3. Clear Output
If notebook gets slow:
**Cell → All Output → Clear**

### 4. Restart Kernel
If something breaks:
**Kernel → Restart & Run All**

### 5. Export HTML
To share results:
**File → Download as → HTML**

---

## 🎯 Key Outputs to Check

### After Running Cell 4:
```
✓ punkt downloaded successfully
✓ stopwords downloaded successfully
✓ wordnet downloaded successfully
```

### After Running Cell 20:
```
Processing column: quick_checks
Processing column: diagnostic_steps
Processing column: recommended_actions
Main dataset preprocessing completed!
```

### After Running Cell 32:
```
Main Dataset TF-IDF Matrix Shape: (250, 500)
Number of unique features: 500
```

### After Running Cell 39-41:
```
Processed datasets saved!
TF-IDF vectorizers saved!
TF-IDF matrices saved!
```

---

## 🚀 Next Steps After Notebook

1. **Test the Chatbot**
   ```cmd
   run_server.bat
   ```

2. **Check Output Files**
   ```cmd
   dir data\*.csv
   dir data\*.pkl
   dir data\*.npz
   ```

3. **Use in Chatbot**
   The chatbot automatically loads these files:
   - `knowledge_base.py` uses TF-IDF files
   - Semantic search uses processed datasets

---

## 📚 Understanding the Preprocessing

### Input (Raw Text):
```
"My car's engine won't start! There's a clicking noise."
```

### Step 1: Clean
```
"my car's engine won't start! there's a clicking noise."
```

### Step 2: Expand Contractions
```
"my car's engine will not start! there is a clicking noise."
```

### Step 3: Remove Special Characters
```
"my cars engine will not start there is a clicking noise"
```

### Step 4: Remove Stopwords
```
"cars engine start clicking noise"
```

### Step 5: Lemmatize
```
"car engine start click noise"
```

This makes matching easier!

---

## 🎨 Customization

### Change Stopwords
Edit in cell 15:
```python
self.automotive_keywords = {
    'engine', 'start', 'brake', 'battery', 'oil', 'fuel',
    # Add more keywords to keep
}
```

### Change TF-IDF Settings
Edit in cell 32:
```python
tfidf_vectorizer_main = TfidfVectorizer(
    max_features=500,      # Change number of features
    ngram_range=(1, 3),    # Change n-gram range
    min_df=2,              # Minimum document frequency
    max_df=0.8             # Maximum document frequency
)
```

### Add More Test Queries
Edit in cell 37:
```python
test_queries = [
    "My car engine won't start",
    "Add your test query here",
]
```

---

## ✅ Success Checklist

After running the notebook, you should have:

- ✅ No error messages
- ✅ 6 new files in `data/` folder
- ✅ Word cloud visualizations
- ✅ Frequency charts
- ✅ Similarity search results
- ✅ Final statistics summary

---

## 🎉 Ready!

Your NLP preprocessing notebook is fixed and ready to use!

**Run it now:**
```cmd
jupyter notebook nlp_preprocessing.ipynb
```

**Then run your chatbot:**
```cmd
run_server.bat
```

**Everything is connected and working! 🚀**
