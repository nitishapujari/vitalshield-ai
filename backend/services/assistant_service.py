import re
import json
import datetime
from typing import Optional, Dict, Any, List

def is_emergency_query(message: str) -> bool:
    # Patterns covering chest pain, breathing difficulties, stroke symptoms, suicide, self harm, and medical emergency.
    emergency_patterns = [
        r'\bsuicid(e|al)\b', r'\bkill\s+myself\b', r'\bself[\s-]*harm\b', r'\bend\s+my\s+life\b',
        r'\bwant\s+to\s+die\b', r'\bbetter\s+off\s+dead\b',
        r'\bchest\s+pain\b', r'\bheart\s+attack\b', r'\bpain\s+in\s+chest\b', r'\bchest\s+pressure\b',
        r'\bleft\s+arm\s+pain\b',
        r"can't\s+breathe", r"cant\s+breathe", r'\bdifficulty\s+breathing\b',
        r'\bshort(ness)?\s+of\s+breath\b', r'\bsuffocat(ing|e)?\b', r'\bgasping\s+for\s+air\b',
        r'\bstroke\b', r'\bface\s+droop(ing)?\b', r'\barm\s+weakness\b', r'\bspeech\s+slur(red)?\b',
        r'\bslur(red)?\s+speech\b',
        r'\bmedical\s+emergency\b', r'\bcall\s+(an\s+)?ambulance\b', r'\bcall\s+911\b',
        r'\bpoisoned\b', r'\bsevere\s+allergic\s+reaction\b', r'\banaphylaxis\b',
        r'\blost\s+consciousness\b', r'\bpassed\s+out\b',
        r'\bcollaps(e|ed)\b', r'\bbleed(ing)?\b', r'\b(hurt|harm)\s+my(self|\s+self)\b'
    ]
    return any(re.search(pattern, message.lower()) for pattern in emergency_patterns)

def get_regional_crisis_response(locale: Optional[str]) -> str:
    country = "UNKNOWN"
    if locale:
        parts = locale.replace("-", "_").split("_")
        if len(parts) > 1:
            country = parts[1].upper()
        else:
            country = parts[0].upper()

    if country == "US":
        emergency_number = "911"
        crisis_number = "\n• Call or text the Suicide & Crisis Lifeline at **988** (available 24/7, free, and confidential)."
    elif country == "CA":
        emergency_number = "911"
        crisis_number = "\n• Call or text the Suicide Crisis Helpline at **988** (available 24/7, free, and confidential)."
    elif country in ["GB", "UK"]:
        emergency_number = "999"
        crisis_number = "\n• Call the Samaritans at **116 123** or call NHS **111** for mental health support."
    elif country == "IN":
        emergency_number = "112"
        crisis_number = "\n• Call the Tele-MANAS mental health helpline at **14416** or **1800 891 4416** (available 24/7, free, and confidential)."
    elif country == "AU":
        emergency_number = "000"
        crisis_number = "\n• Call Lifeline at **13 11 14** for mental health and crisis support."
    else:
        return (
            "🚨 **CRITICAL SAFETY NOTICE** 🚨\n\n"
            "If you are experiencing chest pain, difficulty breathing, stroke-like symptoms, "
            "thoughts of self-harm, or any other life-threatening medical emergency, "
            "**please seek immediate medical assistance.**\n\n"
            "• **Contact your local emergency services, emergency medical provider, crisis hotline, or trusted emergency contact immediately.**\n"
            "• Go to the nearest Emergency Room (ER) or hospital.\n\n"
            "VitalShield AI is an educational wellness companion and **cannot provide medical diagnosis, emergency triage, or crisis intervention.**"
        )

    return (
        f"🚨 **CRITICAL SAFETY NOTICE** 🚨\n\n"
        f"If you are experiencing chest pain, difficulty breathing, stroke-like symptoms, "
        f"thoughts of self-harm, or any other life-threatening medical emergency, "
        f"**please seek immediate medical assistance.**\n\n"
        f"• **Call {emergency_number}** immediately.\n"
        f"• Go to the nearest Emergency Room (ER) or hospital.{crisis_number}\n\n"
        f"VitalShield AI is an educational wellness companion and **cannot provide medical diagnosis, emergency triage, or crisis intervention.**"
    )

def match_word_keywords(msg: str, keywords: list) -> bool:
    return any(re.search(r'\b' + re.escape(k) + r'\b', msg) for k in keywords)

def map_category_title(title: str) -> str:
    t = title.lower()
    if "sleep" in t: return "sleep"
    if "activity" in t: return "Physical activity"
    if "pressure" in t: return "Blood pressure"
    if "heart" in t: return "Heart rate"
    if "glucose" in t: return "Fasting glucose"
    return title

def generate_assistant_response(message: str, context: Dict[str, Any], history: List[Dict[str, str]]) -> str:
    """
    Mock LLM Provider / Generation Layer.
    Utilizes bounded context (Profile, Prediction, Vitals, History) to generate a response.
    Can later be replaced by OpenAI or Gemini API call without changing the router architecture.
    """
    message_lower = message.strip().lower()
    is_active_session = len(history) > 0

    # Context extraction
    profile_name = context.get("profile_name", "User")
    pred_data = context.get("prediction", {})
    categories = pred_data.get("categories", [])
    highest_opt = pred_data.get("highestImpactOpportunity")
    secondary_opt = pred_data.get("secondaryOpportunity")
    stable_metrics = pred_data.get("stableMetrics", [])

    def find_cat(title):
        for c in categories:
            if c.get("categoryTitle") == title:
                return c
        return None

    improvement_keywords = ["improve", "recommend", "advice", "better", "help", "fix", "weakest", "attention", "focus"]
    is_improvement = match_word_keywords(message_lower, improvement_keywords) or "what should i do" in message_lower

    if not message_lower:
        if is_active_session:
            return "How else can I help you support your wellness journey today?"
        else:
            return f"Hello {profile_name}. I am here to support your wellness journey in an emotionally safe, encouraging space. How can I help you understand your resting patterns, movement, or daily vitals today?"

    elif match_word_keywords(message_lower, ["sleep", "rest", "night"]):
        cat = find_cat("Sleep Wellness")
        if cat:
            return f"Based on your latest wellness snapshot, {cat.get('insight', '')}\n\nTo optimize this: {cat.get('recommendation', '')}"
        else:
            return "Complete a daily check-in with your sleep hours to unlock personalized sleep insights."

    elif match_word_keywords(message_lower, ["step", "steps", "active", "activity", "movement", "exercise", "walk"]):
        cat = find_cat("Activity Wellness")
        if cat:
            return f"Based on your latest wellness snapshot, {cat.get('insight', '')}\n\nTo optimize this: {cat.get('recommendation', '')}"
        else:
            return "Complete a daily check-in with your step count to unlock activity insights."

    elif match_word_keywords(message_lower, ["stress", "calm", "anxious"]):
        return "When stress rises, taking a few deep, slow breaths can help settle your nervous system. Inhaling for four counts and exhaling for six counts is a gentle way to find your center. How is your stress feeling today?"

    elif match_word_keywords(message_lower, ["glucose", "sugar", "blood sugar"]):
        cat = find_cat("Glucose Wellness")
        if cat:
            return f"Based on your latest wellness snapshot, {cat.get('insight', '')}\n\nTo optimize this: {cat.get('recommendation', '')}"
        else:
            return "Complete a daily check-in with your glucose readings to unlock glucose insights."

    elif match_word_keywords(message_lower, ["bp", "pressure", "blood pressure", "systolic", "diastolic"]):
        cat = find_cat("Blood Pressure Wellness")
        if cat:
            return f"Based on your latest wellness snapshot, {cat.get('insight', '')}\n\nTo optimize this: {cat.get('recommendation', '')}"
        else:
            return "Complete a daily check-in with your blood pressure to unlock vascular insights."

    elif match_word_keywords(message_lower, ["diet", "nutrition", "food", "eat"]):
        glu_cat = find_cat("Glucose Wellness")
        bp_cat = find_cat("Blood Pressure Wellness")
        diet_advices = []
        if glu_cat and glu_cat.get("recommendation"):
            diet_advices.append(f"Glucose: {glu_cat['recommendation']}")
        if bp_cat and bp_cat.get("recommendation"):
            diet_advices.append(f"Circulation: {bp_cat['recommendation']}")

        if diet_advices:
            return "Based on your latest wellness snapshot, here is your nutrition guidance:\n\n" + "\n\n".join(diet_advices)
        else:
            return "Nourishing your body with a balanced diet filled with protein, calcium, fiber, and complex carbohydrates is wonderful for supporting steady energy. Complete a daily check-in to see personalized dietary guidance."

    elif is_improvement:
        if not pred_data:
            return "I don't have enough wellness data to make specific recommendations yet. Complete a few daily check-ins so we can identify areas to improve first!"
        elif not highest_opt:
            return "Your wellness categories are all in the optimal range (Score 85+)! You are doing fantastic. Maintain your current sleep, movement, and nutrition habits to sustain this balance."
        else:
            lines = []
            highest_title = map_category_title(highest_opt['categoryTitle'])
            lines.append(f"Looking at your recent check-in, I suggest prioritizing your **{highest_title}** first (Impact: {highest_opt['impactLevel']}, Estimate: +{highest_opt.get('scoreImprovementEstimate', 0):.1f} points).\n{highest_opt['insight']}\nTo support this: {highest_opt['recommendation']}")

            sec_title = secondary_opt['categoryTitle'] if secondary_opt else None
            if secondary_opt:
                secondary_title = map_category_title(secondary_opt['categoryTitle'])
                lines.append(f"\nSecondary opportunity to optimize: **{secondary_title}** (Impact: {secondary_opt['impactLevel']}, Estimate: +{secondary_opt.get('scoreImprovementEstimate', 0):.1f} points).\n{secondary_opt['insight']}\nTo support this: {secondary_opt['recommendation']}")

            for c in categories:
                prio = c.get("recommendationPriority") or c.get("severity") or c.get("trend") or ""
                if prio in ["Critical", "Warning", "needsAttention"]:
                    c_title = c.get("categoryTitle") or c.get("title") or ""
                    if c_title not in [highest_opt['categoryTitle'], sec_title]:
                        other_title = map_category_title(c_title)
                        lines.append(f"\nOther area to monitor: **{other_title}** (Impact: {c.get('impactLevel', 'Low')}, Estimate: +{c.get('scoreImprovementEstimate', 0.0):.1f} points).\n{c.get('insight')}\nTo support this: {c.get('recommendation')}")

            if stable_metrics:
                stable_clean = [map_category_title(s) for s in stable_metrics]
                lines.append(f"\nStable metrics currently in optimal ranges: " + ", ".join(stable_clean))
            return "\n".join(lines)

    elif match_word_keywords(message_lower, ["ask", "ask you", "say", "said", "just", "previous", "earlier", "before", "last message"]):
        if history:
            # Look for the last user message in the history
            last_user_msg = None
            for h in reversed(history):
                if h["role"].lower() == "user":
                    last_user_msg = h["content"]
                    break

            if last_user_msg:
                return f"You previously asked: '{last_user_msg}'"
        return "We don't have any previous messages in this session yet."

    # Default fallback
    return "I am here to assist you with your health and wellness journey. I can provide insights based on your recent check-ins or offer general guidance on sleep, activity, and nutrition."
