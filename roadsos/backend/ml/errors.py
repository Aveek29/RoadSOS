"""Custom exception types for the ML inference layer.

These are intentionally small and explicit so the HTTP layer can map each one to
a precise status code without leaking internals to clients.
"""


class MlError(Exception):
    """Base class for all ML-layer errors."""


class FeatureValidationError(MlError):
    """Raised when a prediction request fails schema validation.

    ``details`` is a list of human-readable, field-scoped problems that is safe
    to return to API clients.
    """

    def __init__(self, message, details=None):
        super().__init__(message)
        self.message = message
        self.details = details or []


class ModelArtifactError(MlError):
    """Raised when the model artifact is missing, corrupt or unreadable."""


class ModelUnavailableError(MlError):
    """Raised when the model could not be loaded and inference is unavailable."""
