"""Structured logging setup."""

import logging
import os
import sys
from logging.handlers import RotatingFileHandler


def setup_logger(name: str = "trading_bot", log_file: str = "logs/trading_bot.log",
                 level: str = "INFO") -> logging.Logger:
    os.makedirs(os.path.dirname(log_file), exist_ok=True)

    logger = logging.getLogger(name)
    logger.setLevel(getattr(logging, level.upper(), logging.INFO))

    fmt = logging.Formatter(
        "%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )

    ch = logging.StreamHandler(sys.stdout)
    ch.setFormatter(fmt)
    logger.addHandler(ch)

    fh = RotatingFileHandler(log_file, maxBytes=10 * 1024 * 1024, backupCount=5)
    fh.setFormatter(fmt)
    logger.addHandler(fh)

    return logger


def get_logger(name: str = "trading_bot") -> logging.Logger:
    return logging.getLogger(name)
