"""
Text Analysis API Endpoint
Analyzes text messages for phishing, scams, and other threats
"""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional
import re

router = APIRouter()


class TextAnalysisRequest(BaseModel):
    text: str


class TextAnalysisResponse(BaseModel):
    riskScore: int
    threats: List[str]
    patterns: List[str]
    urls: List[str]
    explanation: str
    isSafe: bool


# Threat patterns
URGENCY_PATTERNS = [
    "urgent", "immediately", "act now", "limited time",
    "expires today", "last chance", "don't miss", "hurry",
    "within 24 hours", "account suspended", "account blocked"
]

PHISHING_PATTERNS = [
    "verify your account", "confirm your identity",
    "update your payment", "click here to login",
    "reset your password", "suspicious activity",
    "unauthorized access", "security alert"
]

FAKE_OFFER_PATTERNS = [
    "you have won", "congratulations", "selected winner",
    "claim your prize", "free gift", "lottery winner",
    "million dollars", "exclusive offer"
]

FINANCIAL_PATTERNS = [
    "bank account", "credit card", "transfer money",
    "send money", "wire transfer", "bitcoin",
    "investment opportunity", "guaranteed returns"
]

SUSPICIOUS_DOMAINS = [
    "bit.ly", "tinyurl", "goo.gl", "t.co",
    "ow.ly", "is.gd", "buff.ly", "adf.ly"
]


def analyze_text_content(text: str) -> dict:
    """
    Analyze text for phishing and scam indicators.
    """
    lower_text = text.lower()
    risk_score = 0
    threats = []
    patterns = []
    
    # Extract URLs
    url_pattern = r'https?://[^\s]+|www\.[^\s]+'
    urls = re.findall(url_pattern, text, re.IGNORECASE)
    
    # Check for suspicious shortened URLs
    for url in urls:
        for domain in SUSPICIOUS_DOMAINS:
            if domain in url.lower():
                risk_score += 25
                patterns.append(f"Shortened URL: {domain}")
                if "suspiciousLink" not in threats:
                    threats.append("suspiciousLink")
    
    # Check urgency patterns
    for pattern in URGENCY_PATTERNS:
        if pattern in lower_text:
            risk_score += 15
            patterns.append(f'Urgency: "{pattern}"')
            if "urgency" not in threats:
                threats.append("urgency")
    
    # Check phishing patterns
    for pattern in PHISHING_PATTERNS:
        if pattern in lower_text:
            risk_score += 20
            patterns.append(f'Phishing: "{pattern}"')
            if "phishing" not in threats:
                threats.append("phishing")
    
    # Check fake offer patterns
    for pattern in FAKE_OFFER_PATTERNS:
        if pattern in lower_text:
            risk_score += 20
            patterns.append(f'Fake offer: "{pattern}"')
            if "fakeOffer" not in threats:
                threats.append("fakeOffer")
    
    # Check financial scam patterns
    for pattern in FINANCIAL_PATTERNS:
        if pattern in lower_text:
            risk_score += 15
            patterns.append(f'Financial: "{pattern}"')
            if "financialScam" not in threats:
                threats.append("financialScam")
    
    # Clamp score
    risk_score = min(100, max(0, risk_score))
    
    # Generate explanation
    if risk_score == 0:
        explanation = "No threats detected. Message appears safe."
    elif risk_score < 30:
        explanation = "Low risk. Minor patterns found but likely safe."
    elif risk_score < 60:
        threat_str = ", ".join(threats)
        explanation = f"Moderate risk. Found indicators: {threat_str}. Verify sender."
    else:
        threat_str = ", ".join(threats)
        explanation = f"High risk! Strong indicators: {threat_str}. Do not click links."
    
    return {
        "riskScore": risk_score,
        "threats": threats,
        "patterns": patterns[:10],  # Limit to top 10 patterns
        "urls": urls,
        "explanation": explanation,
        "isSafe": risk_score < 30
    }


@router.post("/text", response_model=TextAnalysisResponse)
async def analyze_text(request: TextAnalysisRequest):
    """
    Analyze text message for phishing, scams, and threats.
    
    Accepts: Plain text content
    Returns: Risk score, detected threats, and explanation
    """
    if not request.text or len(request.text.strip()) < 10:
        raise HTTPException(
            status_code=400,
            detail="Text must be at least 10 characters"
        )
    
    if len(request.text) > 5000:
        raise HTTPException(
            status_code=400,
            detail="Text must be less than 5000 characters"
        )
    
    try:
        result = analyze_text_content(request.text)
        return TextAnalysisResponse(**result)
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Analysis failed: {str(e)}"
        )
