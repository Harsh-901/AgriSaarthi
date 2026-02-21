"""
Claims App - Serializers
"""

from rest_framework import serializers


class WeatherAlertSerializer(serializers.Serializer):
    id = serializers.UUIDField(read_only=True)
    alert_type = serializers.CharField()
    severity = serializers.CharField()
    condition_text = serializers.CharField()
    temp_c = serializers.DecimalField(max_digits=5, decimal_places=1)
    humidity = serializers.IntegerField()
    precip_mm = serializers.DecimalField(max_digits=7, decimal_places=1)
    wind_kph = serializers.DecimalField(max_digits=6, decimal_places=1)
    location_name = serializers.CharField()
    triggered_at = serializers.DateTimeField()
    is_acknowledged = serializers.BooleanField()
    has_damage = serializers.BooleanField()


class InsuranceClaimListSerializer(serializers.Serializer):
    id = serializers.UUIDField(read_only=True)
    claim_id = serializers.CharField()
    loss_type = serializers.CharField()
    status = serializers.CharField()
    date_of_calamity = serializers.DateField()
    area_affected = serializers.DecimalField(max_digits=10, decimal_places=2)
    hours_remaining = serializers.SerializerMethodField()
    is_within_deadline = serializers.BooleanField()
    evidence_count = serializers.SerializerMethodField()
    created_at = serializers.DateTimeField()

    def get_hours_remaining(self, obj):
        return obj.hours_remaining

    def get_evidence_count(self, obj):
        return len(obj.evidence_photos) if obj.evidence_photos else 0


class InsuranceClaimDetailSerializer(serializers.Serializer):
    id = serializers.UUIDField(read_only=True)
    claim_id = serializers.CharField()
    loss_type = serializers.CharField()
    status = serializers.CharField()
    date_of_calamity = serializers.DateField()
    survey_number = serializers.CharField()
    area_affected = serializers.DecimalField(max_digits=10, decimal_places=2)
    damage_description = serializers.CharField()
    claim_form_data = serializers.JSONField()
    evidence_photos = serializers.JSONField()
    attached_documents = serializers.JSONField()
    deadline = serializers.DateTimeField()
    hours_remaining = serializers.SerializerMethodField()
    is_within_deadline = serializers.BooleanField()
    admin_notes = serializers.CharField()
    rejection_reason = serializers.CharField()
    submitted_at = serializers.DateTimeField()
    created_at = serializers.DateTimeField()
    updated_at = serializers.DateTimeField()

    def get_hours_remaining(self, obj):
        return obj.hours_remaining


class AcknowledgeAlertSerializer(serializers.Serializer):
    alert_id = serializers.UUIDField(required=True)
    has_damage = serializers.BooleanField(required=True)


class CreateClaimSerializer(serializers.Serializer):
    alert_id = serializers.UUIDField(required=False, allow_null=True)
    loss_type = serializers.CharField(required=False, default='')
    area_affected = serializers.DecimalField(
        max_digits=10, decimal_places=2, required=False, default=0
    )
    damage_description = serializers.CharField(required=False, default='')
    survey_number = serializers.CharField(required=False, default='')
