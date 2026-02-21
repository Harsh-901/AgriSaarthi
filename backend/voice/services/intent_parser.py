"""
Voice App - Intent Parser Service
Parses voice text input into structured intents
"""

import re
from typing import Dict, Any, Optional, List
from dataclasses import dataclass
from enum import Enum


class Intent(Enum):
    """Supported voice intents"""
    SHOW_ELIGIBLE_SCHEMES = "show_eligible_schemes"
    APPLY_SCHEME = "apply_scheme"
    CHECK_STATUS = "check_status"
    VIEW_PROFILE = "view_profile"
    LIST_APPLICATIONS = "list_applications"
    VIEW_DOCUMENTS = "view_documents"
    HELP = "help"
    UNKNOWN = "unknown"


@dataclass
class ParsedIntent:
    """Parsed intent result"""
    intent: Intent
    confidence: float
    entities: Dict[str, Any]
    original_text: str


class IntentParser:
    """
    Multilingual intent parser for voice commands.
    Supports Hindi, Marathi, and English.
    """
    
    # Intent patterns for different languages
    INTENT_PATTERNS = {
        Intent.SHOW_ELIGIBLE_SCHEMES: {
            'hindi': [
                r'(मेरी|मुझे).*(योजना|स्कीम).*(दिखाओ|बताओ|दिखा दो)',
                r'(कौन सी|कौनसी).*(योजना|स्कीम)',
                r'(योजना|स्कीम).*(देखना|देखनी)',
                r'पात्र.*योजना',
                r'eligible.*scheme',
            ],
            'marathi': [
                r'(माझ्या|मला).*(योजना|स्कीम).*(दाखवा|सांगा)',
                r'(कोणत्या|कुठल्या).*(योजना|स्कीम)',
                r'योजना.*पहायच्या',
            ],
            'english': [
                r'show.*(my|me).*scheme',
                r'eligible.*scheme',
                r'what.*scheme.*(can|eligible)',
                r'list.*scheme',
                r'my.*scheme',
            ]
        },
        Intent.APPLY_SCHEME: {
            'hindi': [
                r'(आवेदन|अप्लाई).*(करो|कर दो|करना)',
                r'योजना.*(के लिए|में).*(आवेदन|अप्लाई)',
                r'(इस|इसके).*(आवेदन|अप्लाई)',
            ],
            'marathi': [
                r'अर्ज.*करा',
                r'योजना.*अर्ज',
                r'अप्लाय.*करा',
            ],
            'english': [
                r'apply.*(for|to).*scheme',
                r'submit.*application',
                r'apply.*(this|now)',
            ]
        },
        Intent.CHECK_STATUS: {
            'hindi': [
                r'(आवेदन|अप्लीकेशन).*(स्थिति|स्टेटस)',
                r'(स्थिति|स्टेटस).*(देखो|बताओ|दिखाओ)',
                r'मेरा.*आवेदन.*कहां',
            ],
            'marathi': [
                r'अर्ज.*स्थिती',
                r'स्टेटस.*दाखवा',
            ],
            'english': [
                r'(check|show|what).*(status|application)',
                r'application.*status',
                r'my.*application',
            ]
        },
        Intent.VIEW_PROFILE: {
            'hindi': [
                r'(मेरी|मेरा).*(प्रोफाइल|जानकारी)',
                r'प्रोफाइल.*(देखो|दिखाओ)',
            ],
            'marathi': [
                r'माझी.*माहिती',
                r'प्रोफाइल.*दाखवा',
            ],
            'english': [
                r'(my|show).*profile',
                r'my.*details',
            ]
        },
        Intent.LIST_APPLICATIONS: {
            'hindi': [
                r'(मेरे|मेरी).*(सारे|सभी).*(आवेदन)',
                r'(आवेदन|अप्लीकेशन).*(लिस्ट|सूची)',
            ],
            'marathi': [
                r'(माझे|माझी).*(सर्व|सगळे).*(अर्ज)',
                r'अर्ज.*(यादी|लिस्ट)',
            ],
            'english': [
                r'(all|list).*(my)?.*(application)',
                r'my.*applications',
            ]
        },
        Intent.VIEW_DOCUMENTS: {
            'hindi': [
                r'(मेरे|मेरी).*(दस्तावेज|डॉक्युमेंटस|पेपर)',
                r'दस्तावेज.*(दिखाओ|देखने)',
            ],
            'marathi': [
                r'कागदपत्रे.*दाखवा',
                r'डॉक्युमेंटस.*पहायचे',
            ],
            'english': [
                r'(my|show).*document(s)?',
                r'view.*document(s)?',
                r'upload.*doc(s)?',
            ]
        },
        Intent.HELP: {
            'hindi': [
                r'(मदद|सहायता)',
                r'(क्या|कैसे).*(कर सकत|करू)',
            ],
            'marathi': [
                r'मदत',
            ],
            'english': [
                r'help',
                r'what can (you|i) do',
            ]
        }
    }
    
    @classmethod
    def parse(cls, text: str, language: str = 'hindi') -> ParsedIntent:
        """
        Parse voice text into an intent.
        
        Args:
            text: The voice input text
            language: Preferred language (hindi, marathi, english)
        
        Returns:
            ParsedIntent with detected intent and confidence
        """
        text_lower = text.lower().strip()
        
        # Try to match patterns for each intent
        best_match = None
        best_confidence = 0.0
        
        for intent, patterns_by_lang in cls.INTENT_PATTERNS.items():
            # Check preferred language first
            languages_to_check = [language, 'hindi', 'english', 'marathi']
            seen = set()
            languages_to_check = [x for x in languages_to_check if not (x in seen or seen.add(x))]
            
            for lang in languages_to_check:
                if lang in patterns_by_lang:
                    for pattern in patterns_by_lang[lang]:
                        if re.search(pattern, text_lower, re.IGNORECASE | re.UNICODE):
                            # Higher confidence for preferred language match
                            confidence = 0.9 if lang == language else 0.7
                            if confidence > best_confidence:
                                best_confidence = confidence
                                best_match = intent
                            break
        
        if best_match is not None:
            return ParsedIntent(
                intent=best_match,
                confidence=best_confidence,
                entities=cls._extract_entities(text, best_match),
                original_text=text
            )
        
        return ParsedIntent(
            intent=Intent.UNKNOWN,
            confidence=0.0,
            entities={},
            original_text=text
        )
    
    @classmethod
    def _extract_entities(cls, text: str, intent: Intent) -> Dict[str, Any]:
        """Extract entities from text based on intent"""
        entities = {}
        
        # Extract scheme name if mentioned
        scheme_patterns = [
            r'(pm[-\s]?kisan|पीएम[-\s]?किसान|प्रधानमंत्री[-\s]?किसान)',
            r'(fasal bima|फसल बीमा)',
            r'(kisan credit|किसान क्रेडिट)',
            r'(soil health|मृदा स्वास्थ्य)',
        ]
        
        for pattern in scheme_patterns:
            match = re.search(pattern, text, re.IGNORECASE | re.UNICODE)
            if match:
                entities['scheme_mention'] = match.group(0)
                break
        
        return entities


class ResponseGenerator:
    """
    Generate localized responses for voice output.
    """
    
    RESPONSES = {
        Intent.SHOW_ELIGIBLE_SCHEMES: {
            'hindi': {
                'success': 'आपके लिए {count} योजनाएं उपलब्ध हैं। {schemes}',
                'no_schemes': 'अभी आपके लिए कोई योजना उपलब्ध नहीं है।',
                'incomplete_profile': 'कृपया पहले अपनी प्रोफाइल पूरी करें।',
            },
            'marathi': {
                'success': 'तुमच्यासाठी {count} योजना उपलब्ध आहेत। {schemes}',
                'no_schemes': 'सध्या तुमच्यासाठी कोणतीही योजना उपलब्ध नाही.',
                'incomplete_profile': 'कृपया प्रथम तुमची प्रोफाइल पूर्ण करा.',
            },
            'english': {
                'success': 'You are eligible for {count} schemes. {schemes}',
                'no_schemes': 'No schemes are currently available for you.',
                'incomplete_profile': 'Please complete your profile first.',
            }
        },
        Intent.APPLY_SCHEME: {
            'hindi': {
                'success': '{scheme_name} के लिए आवेदन सफलतापूर्वक जमा हुआ।',
                'already_applied': 'आपने पहले से इस योजना के लिए आवेदन किया है।',
                'not_eligible': 'आप इस योजना के लिए पात्र नहीं हैं।',
                'scheme_not_found': 'मुझे {scheme_name} आपकी पात्र योजनाओं में नहीं मिली।',
                'specify_scheme': 'आप किस योजना के लिए आवेदन करना चाहते हैं? आप इनके लिए आवेदन कर सकते हैं: {schemes}',
            },
            'marathi': {
                'success': '{scheme_name} साठी अर्ज यशस्वीरित्या सबमिट झाला.',
                'already_applied': 'तुम्ही आधीच या योजनेसाठी अर्ज केला आहे.',
                'not_eligible': 'तुम्ही या योजनेसाठी पात्र नाही.',
                'scheme_not_found': 'मला {scheme_name} आपल्या पात्र योजनांमध्ये आढळली नाही.',
                'specify_scheme': 'तुम्हाला कोणत्या योजनेसाठी अर्ज करायचा आहे? तुम्ही यासाठी अर्ज करू शकता: {schemes}',
            },
            'english': {
                'success': 'Application for {scheme_name} submitted successfully.',
                'already_applied': 'You have already applied for this scheme.',
                'not_eligible': 'You are not eligible for this scheme.',
                'scheme_not_found': ' I could not find {scheme_name} in your eligible schemes.',
                'specify_scheme': 'Which scheme do you want to apply for? You can apply for: {schemes}',
            }
        },
        Intent.CHECK_STATUS: {
            'hindi': {
                'success': 'आपके {count} आवेदन हैं। {status_summary}',
                'no_applications': 'आपने अभी तक कोई आवेदन नहीं किया है।',
            },
            'marathi': {
                'success': 'तुमचे {count} अर्ज आहेत। {status_summary}',
                'no_applications': 'तुम्ही अद्याप कोणताही अर्ज केला नाही.',
            },
            'english': {
                'success': 'You have {count} applications. {status_summary}',
                'no_applications': 'You have not submitted any applications yet.',
            }
        },
        Intent.VIEW_DOCUMENTS: {
            'hindi': 'आपके पास {count} दस्तावेज अपलोड हैं। आप इन्हें यहां देख सकते हैं।',
            'marathi': 'तुमच्याकडे {count} कागदपत्रे अपलोड आहेत. तुम्ही ती येथे पाहू शकता.',
            'english': 'You have {count} documents uploaded. You can view them here.',
        },
        Intent.HELP: {
            'hindi': 'आप मुझसे कह सकते हैं: "मेरी योजनाएं दिखाओ", "आवेदन करो", या "स्थिति बताओ"।',
            'marathi': 'तुम्ही मला सांगू शकता: "माझ्या योजना दाखवा", "अर्ज करा", किंवा "स्थिती सांगा".',
            'english': 'You can say: "Show my schemes", "Apply for scheme", or "Check status".',
        },
        Intent.UNKNOWN: {
            'hindi': 'मुझे समझ नहीं आया। कृपया फिर से कहें।',
            'marathi': 'मला समजले नाही। कृपया पुन्हा सांगा.',
            'english': 'I did not understand. Please try again.',
        }
    }
    
    @classmethod
    def get_response(cls, intent: Intent, language: str, response_type: str = 'success', **kwargs) -> str:
        """
        Get a localized response for the given intent.
        
        Args:
            intent: The intent to respond to
            language: Response language
            response_type: Type of response (success, error, etc.)
            **kwargs: Variables to format into the response
        """
        responses = cls.RESPONSES.get(intent, {})
        
        if isinstance(responses, str):
            return responses
        
        lang_responses = responses.get(language, responses.get('english', {}))
        
        if isinstance(lang_responses, str):
            response = lang_responses
        else:
            response = lang_responses.get(response_type, 'Response not available.')
        
        try:
            return response.format(**kwargs)
        except KeyError:
            return response
