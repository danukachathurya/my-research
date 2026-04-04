"""
Vehicle Troubleshooting Chatbot - Knowledge Base & Semantic Search

This module handles:
- Loading and managing vehicle issue datasets
- Semantic search using TF-IDF and Gemini embeddings
- Matching user queries to known issues
- Retrieving solutions from dataset

Author: Vehicle Chatbot Team
Date: 2025
"""

import pandas as pd
import numpy as np
import pickle
import sys
from typing import List, Dict, Optional, Tuple
from pathlib import Path
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity
from scipy.sparse import load_npz, save_npz

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from src.utils.text_preprocessor import TextPreprocessor
from src.api.gemini_api import GeminiAPI


class KnowledgeBase:
    """
    Knowledge base for vehicle troubleshooting
    """

    def __init__(self,
                 main_dataset_path: str,
                 fallback_dataset_path: str,
                 gemini_api: Optional[GeminiAPI] = None):
        """
        Initialize knowledge base

        Args:
            main_dataset_path: Path to main vehicle issues dataset
            fallback_dataset_path: Path to fallback dataset
            gemini_api: Optional GeminiAPI instance for embeddings
        """
        self.main_dataset_path = main_dataset_path
        self.fallback_dataset_path = fallback_dataset_path
        self.gemini_api = gemini_api

        # Initialize preprocessor
        self.preprocessor = TextPreprocessor(language='english')

        # Load datasets
        self.main_df = None
        self.fallback_df = None
        self.tfidf_vectorizer = None
        self.tfidf_matrix = None

        # Confidence threshold for matches
        self.confidence_threshold = 0.65

        print("Initializing Knowledge Base...")
        self._load_datasets()
        self._initialize_search_engine()
        print("✅ Knowledge Base initialized successfully!")

    def _load_datasets(self):
        """Load main and fallback datasets"""
        try:
            # Load main dataset
            if self.main_dataset_path.endswith('.csv'):
                self.main_df = pd.read_csv(self.main_dataset_path)
            elif self.main_dataset_path.endswith('.xlsx'):
                self.main_df = pd.read_excel(self.main_dataset_path)

            print(f"✅ Loaded main dataset: {len(self.main_df)} records")

            # Load fallback dataset
            if self.fallback_dataset_path.endswith('.csv'):
                self.fallback_df = pd.read_csv(self.fallback_dataset_path)
            elif self.fallback_dataset_path.endswith('.xlsx'):
                self.fallback_df = pd.read_excel(self.fallback_dataset_path)

            print(f"✅ Loaded fallback dataset: {len(self.fallback_df)} records")

        except Exception as e:
            print(f"❌ Error loading datasets: {e}")
            raise

    def _initialize_search_engine(self):
        """Initialize TF-IDF search engine"""
        try:
            # Get project root
            project_root = Path(__file__).parent.parent.parent
            tfidf_vectorizer_path = project_root / 'data' / 'tfidf_vectorizer_main.pkl'
            tfidf_matrix_path = project_root / 'data' / 'tfidf_matrix_main.npz'

            # Check if preprocessed files exist
            try:
                if tfidf_vectorizer_path.exists() and tfidf_matrix_path.exists():
                    self.tfidf_vectorizer = pickle.load(open(tfidf_vectorizer_path, 'rb'))
                    self.tfidf_matrix = load_npz(tfidf_matrix_path)
                    print(">>> Loaded pre-trained TF-IDF model from data folder")
                    return
            except Exception as e:
                print(f">>> Could not load TF-IDF files: {e}")
                print(">>> Building new TF-IDF model...")

            # Create combined text field if not exists
            if 'combined_text_processed' not in self.main_df.columns:
                self._preprocess_datasets()

            # Create TF-IDF vectorizer
            self.tfidf_vectorizer = TfidfVectorizer(
                max_features=500,
                ngram_range=(1, 3),
                min_df=2,
                max_df=0.8
            )

            # Fit and transform
            self.tfidf_matrix = self.tfidf_vectorizer.fit_transform(
                self.main_df['combined_text_processed'].fillna('')
            )

            # Save for future use in data folder
            pickle.dump(self.tfidf_vectorizer, open(tfidf_vectorizer_path, 'wb'))
            save_npz(tfidf_matrix_path, self.tfidf_matrix)

            print(f">>> TF-IDF model trained and saved: {self.tfidf_matrix.shape}")

        except Exception as e:
            print(f"❌ Error initializing search engine: {e}")
            raise

    def _preprocess_datasets(self):
        """Preprocess dataset text fields"""
        print("Preprocessing datasets...")

        # Main dataset columns to process
        text_columns = ['quick_checks', 'diagnostic_steps', 'recommended_actions', 'sri_lanka_notes']

        # Create combined text
        combined_texts = []
        for idx, row in self.main_df.iterrows():
            combined = ' '.join([
                str(row[col]) if pd.notna(row[col]) else ''
                for col in text_columns if col in self.main_df.columns
            ])
            combined_texts.append(combined)

        self.main_df['combined_text'] = combined_texts
        self.main_df['combined_text_processed'] = self.main_df['combined_text'].apply(
            lambda x: self.preprocessor.preprocess_pipeline(x, remove_stops=True, lemmatize=True)
        )

        print("✅ Datasets preprocessed")

    def search_issue(self,
                    query: str,
                    vehicle_model: Optional[str] = None,
                    top_n: int = 5,
                    use_gemini: bool = False) -> List[Dict]:
        """
        Search for similar issues in knowledge base

        Args:
            query: User's query/issue description
            vehicle_model: Optional vehicle model filter
            top_n: Number of top results to return
            use_gemini: Use Gemini embeddings (slower but more accurate)

        Returns:
            List[Dict]: List of matching issues with similarity scores
        """
        # Preprocess query
        query_processed = self.preprocessor.preprocess_pipeline(query)

        if use_gemini and self.gemini_api:
            return self._search_with_gemini(query_processed, vehicle_model, top_n)
        else:
            return self._search_with_tfidf(query_processed, vehicle_model, top_n)

    def _search_with_tfidf(self,
                          query_processed: str,
                          vehicle_model: Optional[str],
                          top_n: int) -> List[Dict]:
        """
        Search using TF-IDF vectors

        Args:
            query_processed: Preprocessed query
            vehicle_model: Optional vehicle model filter
            top_n: Number of results

        Returns:
            List[Dict]: Search results
        """
        # Transform query
        query_vector = self.tfidf_vectorizer.transform([query_processed])

        # Filter by vehicle model if provided
        if vehicle_model:
            mask = self.main_df['model'].str.lower() == vehicle_model.lower()
            filtered_indices = self.main_df[mask].index.tolist()

            if filtered_indices:
                filtered_matrix = self.tfidf_matrix[filtered_indices]
                similarities = cosine_similarity(query_vector, filtered_matrix).flatten()

                # Map back to original indices
                top_indices_filtered = similarities.argsort()[-top_n:][::-1]
                top_indices = [filtered_indices[i] for i in top_indices_filtered]
                top_similarities = similarities[top_indices_filtered]
            else:
                # No matches for vehicle model, search all
                similarities = cosine_similarity(query_vector, self.tfidf_matrix).flatten()
                top_indices = similarities.argsort()[-top_n:][::-1]
                top_similarities = similarities[top_indices]
        else:
            # Search all
            similarities = cosine_similarity(query_vector, self.tfidf_matrix).flatten()
            top_indices = similarities.argsort()[-top_n:][::-1]
            top_similarities = similarities[top_indices]

        # Build results
        results = []
        for idx, similarity in zip(top_indices, top_similarities):
            issue_data = self.main_df.iloc[idx].to_dict()
            results.append({
                'similarity': float(similarity),
                'confidence': float(similarity),
                'issue_id': issue_data.get('id'),
                'vehicle_model': issue_data.get('model'),
                'vehicle_make': issue_data.get('make'),
                'powertrain': issue_data.get('powertrain'),
                'quick_checks': issue_data.get('quick_checks'),
                'diagnostic_steps': issue_data.get('diagnostic_steps'),
                'recommended_actions': issue_data.get('recommended_actions'),
                'sri_lanka_notes': issue_data.get('sri_lanka_notes'),
                'safety_note': issue_data.get('safety_note'),
                'match_type': 'exact' if similarity > 0.8 else 'similar'
            })

        return results

    def _search_with_gemini(self,
                           query_processed: str,
                           vehicle_model: Optional[str],
                           top_n: int) -> List[Dict]:
        """
        Search using Gemini embeddings (more accurate but slower)

        Args:
            query_processed: Preprocessed query
            vehicle_model: Optional vehicle model filter
            top_n: Number of results

        Returns:
            List[Dict]: Search results
        """
        # Get query embedding
        query_embedding = self.gemini_api.get_embeddings(query_processed)

        if not query_embedding:
            # Fallback to TF-IDF if embedding fails
            return self._search_with_tfidf(query_processed, vehicle_model, top_n)

        # TODO: Implement Gemini embedding search
        # For now, fallback to TF-IDF
        return self._search_with_tfidf(query_processed, vehicle_model, top_n)

    def get_best_match(self, query: str, vehicle_model: Optional[str] = None) -> Optional[Dict]:
        """
        Get single best match for query

        Args:
            query: User query
            vehicle_model: Optional vehicle model

        Returns:
            Dict or None: Best match if confidence > threshold
        """
        results = self.search_issue(query, vehicle_model, top_n=1)

        if results and results[0]['confidence'] >= self.confidence_threshold:
            return results[0]
        else:
            return None

    def format_solution(self, issue_data: Dict, language: str = 'english') -> str:
        """
        Format solution from issue data into readable text

        Args:
            issue_data: Issue data dictionary
            language: Output language

        Returns:
            str: Formatted solution
        """
        solution = []

        # Header
        vehicle = f"{issue_data.get('vehicle_make', '')} {issue_data.get('vehicle_model', '')}".strip()
        if vehicle:
            solution.append(f"🚗 Vehicle: {vehicle}")

        if issue_data.get('powertrain'):
            solution.append(f"⚙️ Powertrain: {issue_data['powertrain']}")

        solution.append("")

        # Quick Checks
        if issue_data.get('quick_checks'):
            solution.append("🔍 QUICK CHECKS:")
            solution.append(issue_data['quick_checks'])
            solution.append("")

        # Diagnostic Steps
        if issue_data.get('diagnostic_steps'):
            solution.append("🔧 DIAGNOSTIC STEPS:")
            solution.append(issue_data['diagnostic_steps'])
            solution.append("")

        # Recommended Actions
        if issue_data.get('recommended_actions'):
            solution.append("✅ RECOMMENDED ACTIONS:")
            solution.append(issue_data['recommended_actions'])
            solution.append("")

        # Sri Lanka specific notes
        if issue_data.get('sri_lanka_notes'):
            solution.append("🇱🇰 SRI LANKA NOTES:")
            solution.append(issue_data['sri_lanka_notes'])
            solution.append("")

        # Safety note
        if issue_data.get('safety_note'):
            solution.append("⚠️ SAFETY NOTE:")
            solution.append(issue_data['safety_note'])

        formatted_text = '\n'.join(solution)

        # Translate if needed
        if language == 'sinhala' and self.gemini_api:
            formatted_text = self.gemini_api.translate_text(
                formatted_text,
                'english',
                'sinhala'
            )

        return formatted_text

    def get_fallback_intents(self) -> List[str]:
        """Get list of fallback intents"""
        if 'intent' in self.fallback_df.columns:
            return self.fallback_df['intent'].unique().tolist()
        return []

    def search_fallback(self, query: str, top_n: int = 3) -> List[Dict]:
        """
        Search fallback dataset for similar examples

        Args:
            query: User query
            top_n: Number of results

        Returns:
            List[Dict]: Fallback examples
        """
        query_processed = self.preprocessor.preprocess_pipeline(query)

        # Simple keyword matching for fallback
        results = []
        for idx, row in self.fallback_df.iterrows():
            user_example = str(row.get('user_example', ''))
            if pd.notna(user_example):
                example_processed = self.preprocessor.preprocess_pipeline(user_example)

                # Calculate simple word overlap
                query_words = set(query_processed.split())
                example_words = set(example_processed.split())
                overlap = len(query_words & example_words)
                similarity = overlap / max(len(query_words), len(example_words), 1)

                if similarity > 0.1:
                    results.append({
                        'similarity': similarity,
                        'intent': row.get('intent'),
                        'bot_reply': row.get('bot_reply'),
                        'bot_questions': row.get('bot_questions'),
                        'generic_quick_checks': row.get('generic_quick_checks'),
                        'safety_rules': row.get('safety_rules')
                    })

        # Sort by similarity
        results.sort(key=lambda x: x['similarity'], reverse=True)
        return results[:top_n]

    def get_statistics(self) -> Dict:
        """Get knowledge base statistics"""
        stats = {
            'main_dataset': {
                'total_issues': len(self.main_df),
                'vehicles': self.main_df['model'].unique().tolist() if 'model' in self.main_df.columns else [],
                'powertrains': self.main_df['powertrain'].unique().tolist() if 'powertrain' in self.main_df.columns else []
            },
            'fallback_dataset': {
                'total_scenarios': len(self.fallback_df),
                'intents': self.get_fallback_intents()
            },
            'search_engine': {
                'tfidf_features': self.tfidf_matrix.shape[1] if self.tfidf_matrix is not None else 0,
                'confidence_threshold': self.confidence_threshold
            }
        }
        return stats


# Example usage and testing
if __name__ == "__main__":
    print("=" * 70)
    print("Testing Knowledge Base")
    print("=" * 70)

    try:
        # Initialize knowledge base
        kb = KnowledgeBase(
            main_dataset_path='sri_lanka_vehicle_dataset_5models_englishonly.xlsx',
            fallback_dataset_path='fallback_dataset.xlsx'
        )

        # Test 1: Search for issue
        print("\n1. Testing issue search...")
        query = "My car won't start and I hear clicking noise"
        results = kb.search_issue(query, top_n=3)

        print(f"\nQuery: {query}")
        print(f"Found {len(results)} results:\n")

        for i, result in enumerate(results, 1):
            print(f"{i}. Confidence: {result['confidence']:.3f}")
            print(f"   Vehicle: {result['vehicle_model']}")
            print(f"   Quick Check: {str(result['quick_checks'])[:100]}...")
            print()

        # Test 2: Get best match
        print("\n2. Testing best match...")
        best = kb.get_best_match("brake pedal feels soft")
        if best:
            print(f"Best match found with confidence: {best['confidence']:.3f}")
            print(kb.format_solution(best)[:300] + "...")
        else:
            print("No good match found (confidence < threshold)")

        # Test 3: Statistics
        print("\n3. Knowledge base statistics...")
        stats = kb.get_statistics()
        print(f"Main dataset: {stats['main_dataset']['total_issues']} issues")
        print(f"Vehicles: {', '.join(stats['main_dataset']['vehicles'])}")
        print(f"Fallback dataset: {stats['fallback_dataset']['total_scenarios']} scenarios")

        print("\n" + "=" * 70)
        print("✅ All tests completed successfully!")
        print("=" * 70)

    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
