"""
Documents App - Views
"""

import uuid
from rest_framework import status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser

from .models import Document
from .serializers import DocumentSerializer, DocumentCreateSerializer, DocumentListSerializer
from core.authentication import get_farmer_from_token
from core.storage import upload_document, delete_document
from farmers.models import Farmer


class DocumentListView(APIView):
    """
    GET /api/documents/
    POST /api/documents/
    
    List farmer's documents or upload new one
    """
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]
    
    def get(self, request):
        farmer = get_farmer_from_token(request)
        if not farmer:
            return Response({
                'success': False,
                'message': 'Farmer not found'
            }, status=status.HTTP_404_NOT_FOUND)
        
        documents = Document.objects.filter(farmer=farmer)
        serializer = DocumentListSerializer(documents, many=True)
        
        return Response({
            'success': True,
            'data': {
                'documents': serializer.data,
                'count': documents.count()
            }
        })
    
    def post(self, request):
        farmer = get_farmer_from_token(request)
        if not farmer:
            return Response({
                'success': False,
                'message': 'Farmer not found'
            }, status=status.HTTP_404_NOT_FOUND)

        # Define compulsory document types
        compulsory_types = ['aadhaar', 'pan_card', 'land_certificate', 'seven_twelve', 'eight_a', 'bank_passbook']

        # Check if all compulsory documents are provided
        missing_types = [doc_type for doc_type in compulsory_types if doc_type not in request.FILES]
        if missing_types:
            return Response({
                'success': False,
                'message': f'Missing compulsory documents: {", ".join(missing_types)}'
            }, status=status.HTTP_400_BAD_REQUEST)

        # Collect all document types to upload (compulsory + optional 'other' if present)
        document_types_to_upload = compulsory_types + (['other'] if 'other' in request.FILES else [])

        uploaded_documents = []

        # Upload each document
        for document_type in document_types_to_upload:
            file = request.FILES[document_type]

            # Generate filename using document_type
            file_ext = file.name.split('.')[-1] if '.' in file.name else 'bin'
            filename = f"{document_type}.{file_ext}"

            # Upload to farmer's bucket
            document_url = upload_document(str(farmer.id), file, filename)

            if not document_url:
                # If any upload fails, return error (no partial uploads)
                return Response({
                    'success': False,
                    'message': f'Failed to upload {document_type} to storage'
                }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

            # Create document record
            document = Document.objects.create(
                farmer=farmer,
                document_type=document_type,
                document_url=document_url
            )
            uploaded_documents.append(document)

        # Serialize all uploaded documents
        serializer = DocumentSerializer(uploaded_documents, many=True)

        return Response({
            'success': True,
            'message': 'All documents uploaded successfully',
            'data': {
                'documents': serializer.data,
                'count': len(uploaded_documents)
            }
        }, status=status.HTTP_201_CREATED)


class DocumentDetailView(APIView):
    """
    GET /api/documents/<document_id>/
    DELETE /api/documents/<document_id>/
    """
    permission_classes = [IsAuthenticated]
    
    def get(self, request, document_id):
        farmer = get_farmer_from_token(request)
        if not farmer:
            return Response({
                'success': False,
                'message': 'Farmer not found'
            }, status=status.HTTP_404_NOT_FOUND)
        
        try:
            document = Document.objects.get(id=document_id, farmer=farmer)
            serializer = DocumentSerializer(document)
            return Response({
                'success': True,
                'data': serializer.data
            })
        except Document.DoesNotExist:
            return Response({
                'success': False,
                'message': 'Document not found'
            }, status=status.HTTP_404_NOT_FOUND)
    
    def delete(self, request, document_id):
        farmer = get_farmer_from_token(request)
        if not farmer:
            return Response({
                'success': False,
                'message': 'Farmer not found'
            }, status=status.HTTP_404_NOT_FOUND)
        
        try:
            document = Document.objects.get(id=document_id, farmer=farmer)
            document.delete()
            return Response({
                'success': True,
                'message': 'Document deleted successfully'
            })
        except Document.DoesNotExist:
            return Response({
                'success': False,
                'message': 'Document not found'
            }, status=status.HTTP_404_NOT_FOUND)


class DocumentByFarmerView(APIView):
    """
    GET /api/documents/<farmer_id>/

    List documents for a specific farmer by farmer ID
    """
    permission_classes = [IsAuthenticated]

    def get(self, request, farmer_id):
        authenticated_farmer = get_farmer_from_token(request)
        if not authenticated_farmer:
            return Response({
                'success': False,
                'message': 'Farmer not found'
            }, status=status.HTTP_404_NOT_FOUND)

        try:
            target_farmer = Farmer.objects.get(id=farmer_id)
        except Farmer.DoesNotExist:
            return Response({
                'success': False,
                'message': 'Farmer not found'
            }, status=status.HTTP_404_NOT_FOUND)

        # For now, allow access only if the authenticated farmer is the same as the target farmer
        # This can be adjusted based on requirements (e.g., admin access)
        if authenticated_farmer.id != target_farmer.id:
            return Response({
                'success': False,
                'message': 'Unauthorized to access this farmer\'s documents'
            }, status=status.HTTP_403_FORBIDDEN)

        documents = Document.objects.filter(farmer=target_farmer)
        serializer = DocumentListSerializer(documents, many=True)

        return Response({
            'success': True,
            'data': {
                'documents': serializer.data,
                'count': documents.count()
            }
        })

    def post(self, request, farmer_id):
        authenticated_farmer = get_farmer_from_token(request)
        if not authenticated_farmer:
            return Response({
                'success': False,
                'message': 'Farmer not found'
            }, status=status.HTTP_404_NOT_FOUND)

        try:
            target_farmer = Farmer.objects.get(id=farmer_id)
        except Farmer.DoesNotExist:
            return Response({
                'success': False,
                'message': 'Farmer not found'
            }, status=status.HTTP_404_NOT_FOUND)

        # Define compulsory document types
        compulsory_types = ['aadhaar', 'pan_card', 'land_certificate', 'seven_twelve', 'eight_a', 'bank_passbook']

        # Check if all compulsory documents are provided
        missing_types = [doc_type for doc_type in compulsory_types if doc_type not in request.FILES]
        if missing_types:
            return Response({
                'success': False,
                'message': f'Missing compulsory documents: {", ".join(missing_types)}'
            }, status=status.HTTP_400_BAD_REQUEST)

        # Collect all document types to upload (compulsory + optional 'other' if present)
        document_types_to_upload = compulsory_types + (['other'] if 'other' in request.FILES else [])

        uploaded_documents = []

        # Upload each document
        for document_type in document_types_to_upload:
            file = request.FILES[document_type]

            # Generate filename using document_type
            file_ext = file.name.split('.')[-1] if '.' in file.name else 'bin'
            filename = f"{document_type}.{file_ext}"

            # Upload to farmer's bucket
            document_url = upload_document(str(target_farmer.id), file, filename)

            if not document_url:
                # If any upload fails, return error (no partial uploads)
                return Response({
                    'success': False,
                    'message': f'Failed to upload {document_type} to storage'
                }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

            # Create document record
            document = Document.objects.create(
                farmer=target_farmer,
                document_type=document_type,
                document_url=document_url
            )
            uploaded_documents.append(document)

        # Serialize all uploaded documents
        serializer = DocumentSerializer(uploaded_documents, many=True)

        return Response({
            'success': True,
            'message': 'All documents uploaded successfully',
            'data': {
                'documents': serializer.data,
                'count': len(uploaded_documents)
            }
        }, status=status.HTTP_201_CREATED)
