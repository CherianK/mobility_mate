from pymongo import MongoClient
from dotenv import load_dotenv
import os

# 1) Load environment variables from .env
load_dotenv()
MONGO_URI = os.getenv("MONGO_URI")

# 2) Attempt to connect to MongoDB
try:
    client = MongoClient(MONGO_URI)
    client.server_info()  # Forces a connection attempt; throws if bad credentials
    print("Connected to MongoDB Atlas!")
except Exception as e:
    print("MongoDB connection failed:", e)
    # Optionally raise an error or exit

# 3) Choose the database name that actually contains your data
#    Since you said "test-db" in your screenshot, let's use that:
db = client["mobility-mate"]

# 4) Provide a helper to get a reference to a collection
def get_collection(name: str):
    return db[name]