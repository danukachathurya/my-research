"""
Vehicle Troubleshooting Chatbot - Text Preprocessing Module

This module provides text preprocessing capabilities for both English and Sinhala languages.
It includes functions for cleaning, tokenizing, lemmatizing, and vectorizing text data.

Author: Vehicle Chatbot Team
Date: 2025
"""

import re
import pandas as pd
import numpy as np
from typing import List, Dict, Union, Optional
from collections import Counter

# NLP libraries
import nltk
from nltk.corpus import stopwords
from nltk.tokenize import word_tokenize
from nltk.stem import WordNetLemmatizer, PorterStemmer

# Download required NLTK data (run once)
def download_nltk_data():
    """Download required NLTK data packages"""
    packages = ['punkt', 'stopwords', 'wordnet', 'averaged_perceptron_tagger', 'omw-1.4']
    for package in packages:
        try:
            nltk.download(package, quiet=True)
        except Exception as e:
            print(f"Warning: Could not download {package}: {e}")


class TextPreprocessor:
    """
    Comprehensive text preprocessing class for vehicle troubleshooting chatbot
    Supports both English and Sinhala text processing
    """

    def __init__(self, language: str = 'english'):
        """
        Initialize the TextPreprocessor

        Args:
            language (str): Language for preprocessing ('english' or 'sinhala')
        """
        self.language = language
        self.lemmatizer = WordNetLemmatizer()
        self.stemmer = PorterStemmer()

        # English stopwords
        try:
            self.stop_words_en = set(stopwords.words('english'))
        except:
            download_nltk_data()
            self.stop_words_en = set(stopwords.words('english'))

        # Custom automotive keywords to keep (they're important)
        self.automotive_keywords = {
            'engine', 'start', 'brake', 'battery', 'oil', 'fuel', 'check',
            'light', 'warning', 'noise', 'smell', 'leak', 'hot', 'cold',
            'ac', 'air', 'power', 'speed', 'wheel', 'tire', 'steering',
            'pump', 'filter', 'belt', 'hose', 'coolant', 'transmission',
            'clutch', 'pedal', 'dashboard', 'sensor', 'valve', 'spark',
            'plug', 'alternator', 'radiator', 'exhaust', 'muffler'
        }

        # Remove automotive keywords from stopwords
        self.stop_words_en = self.stop_words_en - self.automotive_keywords

        # Sinhala stopwords (common words)
        self.stop_words_si = {
            'මම', 'මා', 'මගේ', 'අපි', 'අප', 'ඔබ', 'ඔබේ', 'එය', 'එම', 'මේ', 'මෙම',
            'වේ', 'වෙයි', 'ද', 'හා', 'සහ', 'නම්', 'නමුත්', 'සඳහා', 'තුළ', 'හෝ',
            'කර', 'කළ', 'නැහැ', 'නෑ', 'තියෙනවා', 'ඇති', 'ඉන්න', 'වන', 'වී'
        }

    def clean_text(self, text: str) -> str:
        """
        Basic text cleaning - remove special characters, extra spaces

        Args:
            text (str): Input text

        Returns:
            str: Cleaned text
        """
        if pd.isna(text):
            return ""

        text = str(text)

        # Convert to lowercase (only for English)
        if self.language == 'english':
            text = text.lower()

        # Remove URLs
        text = re.sub(r'http\S+|www\S+', '', text)

        # Remove email addresses
        text = re.sub(r'\S+@\S+', '', text)

        # Remove extra whitespace
        text = re.sub(r'\s+', ' ', text)

        # Remove leading/trailing whitespace
        text = text.strip()

        return text

    def remove_special_characters(self, text: str, keep_periods: bool = True) -> str:
        """
        Remove special characters but keep important punctuation

        Args:
            text (str): Input text
            keep_periods (bool): Whether to keep periods

        Returns:
            str: Text with special characters removed
        """
        if keep_periods:
            # Keep letters, numbers, spaces, and periods (including Sinhala Unicode)
            text = re.sub(r'[^a-zA-Z0-9\s.\u0D80-\u0DFF]', '', text)
        else:
            # Keep only letters, numbers, and spaces (including Sinhala Unicode)
            text = re.sub(r'[^a-zA-Z0-9\s\u0D80-\u0DFF]', '', text)

        return text

    def remove_stopwords(self, text: str) -> str:
        """
        Remove stopwords based on language

        Args:
            text (str): Input text

        Returns:
            str: Text with stopwords removed
        """
        try:
            tokens = word_tokenize(text) if self.language == 'english' else text.split()
        except:
            tokens = text.split()

        stop_words = self.stop_words_en if self.language == 'english' else self.stop_words_si

        filtered_tokens = [word for word in tokens if word.lower() not in stop_words]

        return ' '.join(filtered_tokens)

    def lemmatize_text(self, text: str) -> str:
        """
        Lemmatize text (English only)

        Args:
            text (str): Input text

        Returns:
            str: Lemmatized text
        """
        if self.language != 'english':
            return text

        try:
            tokens = word_tokenize(text)
            lemmatized = [self.lemmatizer.lemmatize(word) for word in tokens]
            return ' '.join(lemmatized)
        except:
            return text

    def stem_text(self, text: str) -> str:
        """
        Stem text (English only)

        Args:
            text (str): Input text

        Returns:
            str: Stemmed text
        """
        if self.language != 'english':
            return text

        try:
            tokens = word_tokenize(text)
            stemmed = [self.stemmer.stem(word) for word in tokens]
            return ' '.join(stemmed)
        except:
            return text

    def expand_contractions(self, text: str) -> str:
        """
        Expand common English contractions

        Args:
            text (str): Input text

        Returns:
            str: Text with expanded contractions
        """
        contractions_dict = {
            "won't": "will not",
            "can't": "cannot",
            "n't": " not",
            "'re": " are",
            "'s": " is",
            "'d": " would",
            "'ll": " will",
            "'ve": " have",
            "'m": " am"
        }

        for contraction, expansion in contractions_dict.items():
            text = text.replace(contraction, expansion)

        return text

    def preprocess_pipeline(self,
                          text: str,
                          remove_stops: bool = True,
                          lemmatize: bool = True,
                          stem: bool = False) -> str:
        """
        Complete preprocessing pipeline

        Args:
            text (str): Input text
            remove_stops (bool): Whether to remove stopwords
            lemmatize (bool): Whether to lemmatize (English only)
            stem (bool): Whether to stem (English only)

        Returns:
            str: Fully preprocessed text
        """
        # Step 1: Clean text
        text = self.clean_text(text)

        # Step 2: Expand contractions (English only)
        if self.language == 'english':
            text = self.expand_contractions(text)

        # Step 3: Remove special characters
        text = self.remove_special_characters(text, keep_periods=False)

        # Step 4: Remove stopwords
        if remove_stops:
            text = self.remove_stopwords(text)

        # Step 5: Lemmatize or Stem
        if lemmatize and self.language == 'english':
            text = self.lemmatize_text(text)
        elif stem and self.language == 'english':
            text = self.stem_text(text)

        return text

    def batch_preprocess(self,
                        texts: List[str],
                        remove_stops: bool = True,
                        lemmatize: bool = True,
                        stem: bool = False) -> List[str]:
        """
        Preprocess multiple texts at once

        Args:
            texts (List[str]): List of input texts
            remove_stops (bool): Whether to remove stopwords
            lemmatize (bool): Whether to lemmatize
            stem (bool): Whether to stem

        Returns:
            List[str]: List of preprocessed texts
        """
        return [
            self.preprocess_pipeline(text, remove_stops, lemmatize, stem)
            for text in texts
        ]


class DatasetPreprocessor:
    """
    Dataset-level preprocessing for vehicle troubleshooting datasets
    """

    def __init__(self, language: str = 'english'):
        """
        Initialize DatasetPreprocessor

        Args:
            language (str): Language for preprocessing
        """
        self.text_preprocessor = TextPreprocessor(language=language)

    def preprocess_dataframe(self,
                           df: pd.DataFrame,
                           text_columns: List[str],
                           create_combined: bool = True) -> pd.DataFrame:
        """
        Preprocess all text columns in a DataFrame

        Args:
            df (pd.DataFrame): Input DataFrame
            text_columns (List[str]): List of column names to preprocess
            create_combined (bool): Whether to create a combined text column

        Returns:
            pd.DataFrame: DataFrame with preprocessed columns
        """
        df_processed = df.copy()

        for col in text_columns:
            if col in df_processed.columns:
                print(f"Processing column: {col}")

                # Create cleaned version
                df_processed[f'{col}_cleaned'] = df_processed[col].apply(
                    self.text_preprocessor.clean_text
                )

                # Create fully preprocessed version
                df_processed[f'{col}_processed'] = df_processed[col].apply(
                    lambda x: self.text_preprocessor.preprocess_pipeline(
                        x, remove_stops=True, lemmatize=True
                    )
                )

        # Create combined text field
        if create_combined:
            combined_texts = []
            for idx, row in df_processed.iterrows():
                combined = ' '.join([
                    str(row[col]) if pd.notna(row[col]) else ''
                    for col in text_columns if col in df_processed.columns
                ])
                combined_texts.append(combined)

            df_processed['combined_text'] = combined_texts
            df_processed['combined_text_processed'] = df_processed['combined_text'].apply(
                lambda x: self.text_preprocessor.preprocess_pipeline(
                    x, remove_stops=True, lemmatize=True
                )
            )

        return df_processed

    def get_word_frequency(self,
                          text_series: pd.Series,
                          top_n: int = 20) -> List[tuple]:
        """
        Get top N most frequent words from text series

        Args:
            text_series (pd.Series): Series containing text data
            top_n (int): Number of top words to return

        Returns:
            List[tuple]: List of (word, frequency) tuples
        """
        all_words = []
        for text in text_series:
            if pd.notna(text):
                words = str(text).split()
                all_words.extend(words)

        word_freq = Counter(all_words)
        return word_freq.most_common(top_n)


def detect_language(text: str) -> str:
    """
    Simple language detection for English vs Sinhala

    Args:
        text (str): Input text

    Returns:
        str: 'english' or 'sinhala'
    """
    # Check for Sinhala Unicode characters
    sinhala_pattern = re.compile(r'[\u0D80-\u0DFF]')

    if sinhala_pattern.search(text):
        return 'sinhala'
    else:
        return 'english'


# Initialize NLTK data on module import
try:
    download_nltk_data()
except:
    pass


if __name__ == "__main__":
    # Test the preprocessor
    print("=" * 70)
    print("Testing TextPreprocessor")
    print("=" * 70)

    # Test English
    preprocessor_en = TextPreprocessor(language='english')
    test_text = "My car's engine won't start! There's a strange clicking noise."

    print(f"\nOriginal: {test_text}")
    print(f"Cleaned: {preprocessor_en.clean_text(test_text)}")
    print(f"Preprocessed: {preprocessor_en.preprocess_pipeline(test_text)}")

    # Test Sinhala
    preprocessor_si = TextPreprocessor(language='sinhala')
    test_text_si = "මගේ මෝටර් රථය ස්ටාර්ට් වෙන්නේ නැහැ"

    print(f"\nOriginal: {test_text_si}")
    print(f"Cleaned: {preprocessor_si.clean_text(test_text_si)}")
    print(f"Preprocessed: {preprocessor_si.preprocess_pipeline(test_text_si)}")

    print("\n" + "=" * 70)
    print("TextPreprocessor module is ready to use!")
    print("=" * 70)
