import os

os.environ["DATABASE_URL"] = "sqlite:///./test_geocampo.db"
os.environ["STORAGE_PATH"] = "./test_storage"
os.environ["ORIGINAL_FILES_PATH"] = "./test_storage/originals"
os.environ["PROCESSED_FILES_PATH"] = "./test_storage/processed"
os.environ["PACKAGES_PATH"] = "./test_storage/packages"
os.environ["TEMP_PATH"] = "./test_storage/temp"
os.environ["OBSERVATION_PHOTOS_PATH"] = "./test_storage/photos"
os.environ["CELERY_TASK_ALWAYS_EAGER"] = "true"
os.environ["JWT_SECRET_KEY"] = "test-secret-key-with-more-than-32-characters"
os.environ["BOOTSTRAP_ADMIN_PASSWORD"] = "test_password"
