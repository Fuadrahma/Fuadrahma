"""
ML ensemble price direction predictor.
Uses RandomForest + GradientBoosting + Logistic Regression in a soft-voting ensemble.
No GPU required. Falls back gracefully if scikit-learn is missing.
"""
from __future__ import annotations
import logging
import pickle
from pathlib import Path
from typing import Tuple, Optional, Dict

import numpy as np
import pandas as pd

from trading_bot.strategies.indicators import add_all_indicators

logger = logging.getLogger(__name__)

try:
    from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier, VotingClassifier
    from sklearn.linear_model import LogisticRegression
    from sklearn.preprocessing import StandardScaler
    from sklearn.pipeline import Pipeline
    from sklearn.model_selection import cross_val_score
    SKLEARN_AVAILABLE = True
except ImportError:
    SKLEARN_AVAILABLE = False
    logger.warning("scikit-learn not installed — ML predictor disabled")


class MLPredictor:
    """
    Binary classifier: predicts whether price will go UP (1) or DOWN/FLAT (0)
    over the next N candles.
    """

    MODEL_PATH = Path("trading_bot/data/ml_model.pkl")

    def __init__(self, config=None):
        from trading_bot.config import config as default_config
        cfg = (config or default_config).ml
        self.lookback = cfg.lookback_periods
        self.horizon = cfg.prediction_horizon
        self.min_confidence = cfg.min_confidence
        self.feature_names = cfg.features
        self.model: Optional[Pipeline] = None
        self.is_trained = False
        self._load_model()

    def _build_pipeline(self) -> "Pipeline":
        rf = RandomForestClassifier(n_estimators=100, max_depth=8, n_jobs=-1, random_state=42)
        gb = GradientBoostingClassifier(n_estimators=100, max_depth=4, random_state=42)
        lr = LogisticRegression(max_iter=500, random_state=42)
        voting = VotingClassifier(
            estimators=[("rf", rf), ("gb", gb), ("lr", lr)],
            voting="soft",
        )
        return Pipeline([("scaler", StandardScaler()), ("clf", voting)])

    def _extract_features(self, df: pd.DataFrame) -> pd.DataFrame:
        df = add_all_indicators(df)
        feature_map = {
            "rsi": "rsi", "macd": "macd", "macd_signal": "macd_signal",
            "bb_upper": "bb_upper", "bb_lower": "bb_lower", "bb_mid": "bb_mid",
            "ema_9": "ema_9", "ema_21": "ema_21", "ema_55": "ema_55",
            "volume_ratio": "volume_ratio", "atr": "atr_pct",
            "obv_normalized": "obv", "price_change_1h": "price_change_1",
            "price_change_4h": "price_change_4", "price_change_24h": "price_change_24",
        }
        cols = [feature_map.get(f, f) for f in self.feature_names if feature_map.get(f, f) in df.columns]
        features = df[cols].copy()
        # Normalize OBV
        if "obv" in features.columns:
            obv_std = features["obv"].std()
            features["obv"] = features["obv"] / (obv_std + 1e-9)
        return features.replace([np.inf, -np.inf], np.nan).fillna(0)

    def _create_labels(self, df: pd.DataFrame) -> pd.Series:
        """1 if price rises by >0.5% in next N candles, else 0."""
        future_return = df["close"].pct_change(self.horizon).shift(-self.horizon)
        return (future_return > 0.005).astype(int)

    def train(self, df: pd.DataFrame) -> Dict:
        """Train model on historical OHLCV data."""
        if not SKLEARN_AVAILABLE:
            return {"error": "scikit-learn not available"}

        features = self._extract_features(df)
        labels = self._create_labels(df)

        # Align and drop NaN
        valid_idx = features.dropna().index.intersection(labels.dropna().index)
        valid_idx = valid_idx[self.lookback:]   # skip warm-up
        X = features.loc[valid_idx].values
        y = labels.loc[valid_idx].values

        if len(X) < 100:
            return {"error": f"Not enough data: {len(X)} samples"}

        self.model = self._build_pipeline()

        # Cross-validation score
        cv_scores = cross_val_score(self.model, X, y, cv=5, scoring="accuracy", n_jobs=-1)
        self.model.fit(X, y)
        self.is_trained = True

        metrics = {
            "samples": len(X),
            "cv_accuracy_mean": float(cv_scores.mean()),
            "cv_accuracy_std": float(cv_scores.std()),
            "class_balance": float(y.mean()),
        }
        logger.info("ML model trained: %s", metrics)
        self._save_model()
        return metrics

    def predict(self, df: pd.DataFrame) -> Tuple[int, float]:
        """
        Predict direction for latest candle.
        Returns (prediction: 0/1, confidence: 0.0-1.0).
        """
        if not SKLEARN_AVAILABLE or not self.is_trained or self.model is None:
            return 0, 0.5

        features = self._extract_features(df)
        last_row = features.iloc[[-1]].values
        if np.any(np.isnan(last_row)):
            return 0, 0.5

        proba = self.model.predict_proba(last_row)[0]
        prediction = int(np.argmax(proba))
        confidence = float(np.max(proba))
        return prediction, confidence

    def _save_model(self):
        self.MODEL_PATH.parent.mkdir(parents=True, exist_ok=True)
        with open(self.MODEL_PATH, "wb") as f:
            pickle.dump(self.model, f)
        logger.info("ML model saved to %s", self.MODEL_PATH)

    def _load_model(self):
        if not SKLEARN_AVAILABLE:
            return
        if self.MODEL_PATH.exists():
            with open(self.MODEL_PATH, "rb") as f:
                self.model = pickle.load(f)
            self.is_trained = True
            logger.info("ML model loaded from %s", self.MODEL_PATH)
