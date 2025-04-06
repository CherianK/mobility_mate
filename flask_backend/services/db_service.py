from pymongo import MongoClient
from dotenv import load_dotenv
import os

load_dotenv()
MONGO_URI = os.getenv("MONGO_URI")

try:
    client = MongoClient(MONGO_URI)
    client.server_info()  # Forces a connection attempt
    print("Connected to MongoDB Atlas!")
except Exception as e:
    print("MongoDB connection failed:", e)

db = client["mobilitymate"]

def get_collection(name):
    return db[name]
