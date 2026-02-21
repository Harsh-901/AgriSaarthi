"""
Schemes App - Decision Table Eligibility Engine
Evaluates SchemeRule rows to determine farmer eligibility.
Replaces the old JSON-based EligibilityEngine.
"""

import logging
from typing import List, Dict, Any
from decimal import Decimal, InvalidOperation

logger = logging.getLogger(__name__)


# ============================================================
# Core Decision Table Function (required by spec)
# ============================================================

def get_eligible_schemes_for_farmer(farmer):
    """
    Returns a list of Scheme objects for which the farmer
    satisfies ALL associated SchemeRule rows.

    Performance:
      - Single DB query with prefetch_related (no N+1).
      - Early exit on first failing rule per scheme.
    """
    from schemes.models import Scheme

    schemes = (
        Scheme.objects
        .filter(is_active=True)
        .prefetch_related('schemerule_set')
    )

    eligible = []

    for scheme in schemes:
        # Skip expired schemes
        if scheme.is_expired:
            continue

        rules = scheme.schemerule_set.all()  # already prefetched

        # Schemes with NO rules are available to everyone
        if not rules:
            eligible.append(scheme)
            continue

        # ALL rules must pass (early exit on first failure)
        is_eligible = True
        for rule in rules:
            if not _evaluate_rule(farmer, rule):
                is_eligible = False
                break  # early exit

        if is_eligible:
            eligible.append(scheme)

    return eligible


# ============================================================
# Rule Evaluator
# ============================================================

def _evaluate_rule(farmer, rule) -> bool:
    """
    Evaluate a single SchemeRule against a farmer instance.
    Returns True if the farmer passes this rule, False otherwise.
    """
    field_name = rule.field
    operator = rule.operator.strip()
    rule_value = rule.value.strip()

    # Safely get the farmer attribute
    if not hasattr(farmer, field_name):
        logger.warning(
            "SchemeRule references unknown farmer field '%s' — skipping rule",
            field_name
        )
        return True  # skip unknown fields gracefully

    farmer_value = getattr(farmer, field_name)

    try:
        if operator == 'IN':
            return _evaluate_in(farmer_value, rule_value)
        elif operator in ('<=', '>=', '=='):
            return _evaluate_comparison(farmer_value, operator, rule_value)
        else:
            logger.warning(
                "Unsupported operator '%s' in SchemeRule — skipping rule",
                operator
            )
            return True  # unknown operator → skip gracefully
    except Exception as e:
        logger.error(
            "Error evaluating rule (field=%s, op=%s, val=%s): %s",
            field_name, operator, rule_value, e
        )
        return False  # on error, treat as ineligible


def _evaluate_in(farmer_value, rule_value: str) -> bool:
    """
    IN operator: rule_value is comma-separated.
    Example: rule_value = "Maharashtra,UP"
    """
    allowed = [v.strip().lower() for v in rule_value.split(',')]
    return str(farmer_value).strip().lower() in allowed


def _evaluate_comparison(farmer_value, operator: str, rule_value: str) -> bool:
    """
    Numeric/string comparison for <=, >=, ==.
    Attempts numeric comparison first; falls back to string compare.
    """
    # Try numeric comparison
    try:
        numeric_farmer = Decimal(str(farmer_value))
        numeric_rule = Decimal(rule_value)

        if operator == '<=':
            return numeric_farmer <= numeric_rule
        elif operator == '>=':
            return numeric_farmer >= numeric_rule
        elif operator == '==':
            return numeric_farmer == numeric_rule
    except (InvalidOperation, ValueError, TypeError):
        pass

    # Handle boolean fields (e.g., is_bpl, has_irrigation)
    if isinstance(farmer_value, bool):
        rule_bool = rule_value.strip().lower() in ('true', '1', 'yes')
        if operator == '==':
            return farmer_value == rule_bool
        return False  # <= / >= don't make sense for booleans

    # Fallback: string comparison (case-insensitive)
    str_farmer = str(farmer_value).strip().lower()
    str_rule = rule_value.strip().lower()

    if operator == '==':
        return str_farmer == str_rule
    elif operator == '<=':
        return str_farmer <= str_rule
    elif operator == '>=':
        return str_farmer >= str_rule

    return False


# ============================================================
# Backward-compatible wrapper class
# (keeps voice/views.py, applications/views.py working)
# ============================================================

class EligibilityEngine:
    """
    Backward-compatible wrapper around the Decision Table engine.
    Existing callers can keep using EligibilityEngine.get_eligible_schemes()
    and EligibilityEngine.check_eligibility() without changes.
    """

    @classmethod
    def check_eligibility(cls, farmer, scheme) -> Dict[str, Any]:
        """
        Check if a farmer is eligible for a single scheme
        using its SchemeRule rows.
        """
        rules = scheme.schemerule_set.all()

        matched_rules = []
        failed_rules = []

        for rule in rules:
            passed = _evaluate_rule(farmer, rule)
            entry = {
                'rule': f"{rule.field} {rule.operator} {rule.value}",
                'field': rule.field,
                'message': rule.message or f"{rule.field} {rule.operator} {rule.value}"
            }
            if passed:
                matched_rules.append(entry)
            else:
                failed_rules.append(entry)

        # Document check (keep existing behavior)
        missing_docs = []
        try:
            from documents.models import Document
            farmer_docs = Document.get_farmer_document_types(farmer)
            required_docs = scheme.required_documents or []
            missing_docs = [doc for doc in required_docs if doc not in farmer_docs]
        except Exception:
            pass

        is_eligible = len(failed_rules) == 0

        return {
            'eligible': is_eligible,
            'matched_rules': matched_rules,
            'failed_rules': failed_rules,
            'missing_documents': missing_docs,
            'has_all_documents': len(missing_docs) == 0
        }

    @classmethod
    def get_eligible_schemes(cls, farmer, schemes=None) -> List[Dict[str, Any]]:
        """
        Get all eligible schemes for a farmer (with details).
        """
        if schemes is None:
            eligible_scheme_objs = get_eligible_schemes_for_farmer(farmer)
        else:
            # filter the given queryset through rule evaluation
            eligible_scheme_objs = []
            for scheme in schemes:
                if scheme.is_expired:
                    continue
                rules = scheme.schemerule_set.all()
                if not rules or all(_evaluate_rule(farmer, r) for r in rules):
                    eligible_scheme_objs.append(scheme)

        result = []
        for scheme in eligible_scheme_objs:
            eligibility = cls.check_eligibility(farmer, scheme)
            result.append({
                'scheme': scheme,
                'scheme_id': str(scheme.id),
                'name': scheme.name,
                'name_localized': scheme.get_localized_name(
                    getattr(farmer, 'language', 'english')
                ),
                'description': scheme.get_localized_description(
                    getattr(farmer, 'language', 'english')
                ),
                'benefit_amount': float(scheme.benefit_amount),
                'deadline': str(scheme.deadline) if scheme.deadline else None,
                'eligibility': eligibility,
                'can_apply': eligibility['has_all_documents']
            })

        return result

    @classmethod
    def get_all_schemes_with_eligibility(cls, farmer, schemes=None) -> List[Dict[str, Any]]:
        """
        Get all schemes with eligibility status for a farmer.
        """
        from schemes.models import Scheme

        if schemes is None:
            schemes = (
                Scheme.objects
                .filter(is_active=True)
                .prefetch_related('schemerule_set')
            )

        all_schemes = []
        for scheme in schemes:
            result = cls.check_eligibility(farmer, scheme)
            all_schemes.append({
                'scheme_id': str(scheme.id),
                'name': scheme.name,
                'name_localized': scheme.get_localized_name(
                    getattr(farmer, 'language', 'english')
                ),
                'description': scheme.get_localized_description(
                    getattr(farmer, 'language', 'english')
                ),
                'benefit_amount': float(scheme.benefit_amount),
                'deadline': str(scheme.deadline) if scheme.deadline else None,
                'is_eligible': result['eligible'],
                'eligibility_details': result,
                'is_expired': scheme.is_expired
            })

        return all_schemes
