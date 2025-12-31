"""
RiskGuard Backend API - FastAPI Server
Real-Time AI-Based Digital Risk Detection
"""
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
import uvicorn

# Import analysis modules
from api.endpoints import voice, text, risk

# Create FastAPI app
app = FastAPI(
    title="RiskGuard API",
    description="AI-powered digital risk detection backend",
    version="1.0.0",
)

# CORS middleware for Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(voice.router, prefix="/api/v1/analyze", tags=["Voice Analysis"])
app.include_router(text.router, prefix="/api/v1/analyze", tags=["Text Analysis"])
app.include_router(risk.router, prefix="/api/v1/score", tags=["Risk Scoring"])


@app.get("/")
async def root():
    return {
        "name": "RiskGuard API",
        "version": "1.0.0",
        "status": "running",
        "endpoints": {
            "voice_analysis": "/api/v1/analyze/voice",
            "text_analysis": "/api/v1/analyze/text",
            "risk_scoring": "/api/v1/score/calculate",
        }
    }


@app.get("/health")
async def health_check():
    return {"status": "healthy"}


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
