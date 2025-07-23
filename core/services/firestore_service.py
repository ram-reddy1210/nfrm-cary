import os
from datetime import datetime, timezone
from google.cloud import firestore
from typing import Dict, Any, List
from collections import Counter

# Asynchronous Firestore client, initialized at startup
db: firestore.AsyncClient = None

def initialize_firestore():
    """
    Initializes the asynchronous Firestore client.
    This function should be called once at application startup.
    It uses the project ID from environment variables and connects to the specified database.
    """
    global db
    project_id = os.getenv('GCP_PROJECT_ID', 'ai-agent-repo')
    # The user specified 'ai-agents-db' as the database name (ID).
    # The Firestore client needs this ID during initialization if it's not '(default)'.
    database_id = 'ai-agents-db'
    
    print(f"Initializing Firestore client for project: {project_id}, database: {database_id}")
    try:
        # Application Default Credentials (ADC) will be used automatically.
        db = firestore.AsyncClient(project=project_id, database=database_id)
        print("Firestore client initialized successfully.")
    except Exception as e:
        print(f"Failed to initialize Firestore client: {e}")
        db = None


async def log_api_call(
    api_name: str,
    prompt: str,
    user_details: Dict[str, Any],
    request_data: Dict[str, Any]
):
    """
    Logs the details of an API call to the 'api_logs' collection in Firestore.
    """
    if not db:
        print("Firestore client is not initialized. Skipping log.")
        return

    try:
        collection_ref = db.collection('api_logs')
        log_document = {
            'api_name': api_name,
            'prompt': prompt,
            'user_details': user_details,
            'request_data': request_data,
            'timestamp': datetime.now(timezone.utc)
        }
        await collection_ref.add(log_document)
        print(f"Successfully logged API call for '{api_name}' to Firestore.")
    except Exception as e:
        print(f"Error logging API call to Firestore: {e}")


async def query_api_logs(api_name: str = None, limit: int = 20) -> List[Dict[str, Any]]:
    """
    Queries the 'api_logs' collection in Firestore.

    Args:
        api_name: The name of the API to filter logs by. If None, no filter is applied.
        limit: The maximum number of logs to return.

    Returns:
        A list of log documents.
    """
    if not db:
        print("Firestore client is not initialized. Cannot query logs.")
        return []

    try:
        collection_ref = db.collection('api_logs')
        # Base query ordered by timestamp descending
        query = collection_ref.order_by('timestamp', direction=firestore.Query.DESCENDING)

        # Apply filter if api_name is provided
        if api_name:
            query = query.where(filter=firestore.FieldFilter('api_name', '==', api_name))

        # Apply limit
        query = query.limit(limit)

        documents = []
        async for doc in query.stream():
            doc_data = doc.to_dict()
            # Firestore timestamp needs to be converted to a string for JSON serialization
            if 'timestamp' in doc_data and isinstance(doc_data['timestamp'], datetime):
                doc_data['timestamp'] = doc_data['timestamp'].isoformat()
            documents.append(doc_data)

        print(f"Successfully queried {len(documents)} logs from Firestore.")
        return documents
    except Exception as e:
        print(f"Error querying API logs from Firestore: {e}")
        return []


async def count_collection_with_filters(
    collection_name: str,
    filters: List[Dict[str, Any]]
) -> int:
    """
    Counts documents in a Firestore collection based on a list of filters.

    Args:
        collection_name: The name of the collection to query.
        filters: A list of filter dictionaries. Each dict should have 'field', 'op', and 'value'.

    Returns:
        The number of documents matching the filters.
    """
    if not db:
        print("Firestore client is not initialized. Cannot count documents.")
        return 0

    try:
        query = db.collection(collection_name)

        for f in filters:
            field_filter = firestore.FieldFilter(f['field'], f['op'], f['value'])
            query = query.where(filter=field_filter)

        # Use the count aggregation query for efficiency
        aggregate_query = query.count()
        result = await aggregate_query.get()
        # The result of a count aggregation is a list of AggregateQueryResponse objects
        if result and result[0]:
            count = result[0][0].value
        else:
            count = 0

        print(f"Successfully counted {count} documents in '{collection_name}'.")
        return count
    except Exception as e:
        print(f"Error counting documents in collection '{collection_name}': {e}")
        return 0


async def get_distinct_values(
    collection_name: str,
    field_name: str,
    filters: List[Dict[str, Any]],
    limit: int = 1000
) -> List[Any]:
    """
    Gets distinct values for a specific field from a Firestore collection.

    Note: This operation can be slow on large datasets as it retrieves
    documents to extract unique values. A limit is applied to mitigate this.

    Args:
        collection_name: The name of the collection to query.
        field_name: The name of the field to get distinct values from (supports dot notation for nested fields).
        filters: A list of filter dictionaries to apply before getting distinct values.
        limit: The maximum number of documents to scan for distinct values.

    Returns:
        A list of unique values for the specified field.
    """
    if not db:
        print("Firestore client is not initialized. Cannot get distinct values.")
        return []

    try:
        query = db.collection(collection_name)

        for f in filters:
            field_filter = firestore.FieldFilter(f['field'], f['op'], f['value'])
            query = query.where(filter=field_filter)

        query = query.limit(limit)

        distinct_values = set()
        async for doc in query.stream():
            doc_dict = doc.to_dict()
            # Handle nested fields using dot notation
            keys = field_name.split('.')
            value = doc_dict
            for key in keys:
                value = value.get(key) if isinstance(value, dict) else None
                if value is None:
                    break

            if value is not None:
                distinct_values.add(value)

        print(f"Found {len(distinct_values)} distinct values for field '{field_name}' in '{collection_name}'.")
        return list(distinct_values)
    except Exception as e:
        print(f"Error getting distinct values from collection '{collection_name}': {e}")
        return []

async def group_and_count_by_field(
    collection_name: str,
    group_by_field: str,
    filters: List[Dict[str, Any]],
    limit: int = 1000
) -> Dict[str, int]:
    """
    Groups documents by a specific field and counts the occurrences of each value.

    Note: This operation can be slow on large datasets as it retrieves
    documents to perform client-side aggregation. A limit is applied.

    Args:
        collection_name: The name of the collection to query.
        group_by_field: The field to group by (supports dot notation for nested fields, e.g., 'user_details.user_email').
        filters: A list of filter dictionaries to apply before grouping.
        limit: The maximum number of documents to scan for aggregation.

    Returns:
        A dictionary where keys are the unique values of the group_by_field
        and values are their respective counts.
    """
    if not db:
        print("Firestore client is not initialized. Cannot perform aggregation.")
        return {}

    try:
        query = db.collection(collection_name)

        for f in filters:
            field_filter = firestore.FieldFilter(f['field'], f['op'], f['value'])
            query = query.where(filter=field_filter)

        query = query.limit(limit)

        counts = Counter()
        async for doc in query.stream():
            doc_dict = doc.to_dict()
            
            # Helper to get nested values from a dictionary using dot notation
            keys = group_by_field.split('.')
            value = doc_dict
            for key in keys:
                value = value.get(key) if isinstance(value, dict) else None
                if value is None:
                    break
            
            if value is not None:
                counts[str(value)] += 1 # Ensure key is a string

        print(f"Successfully grouped and counted by '{group_by_field}' in '{collection_name}'.")
        return dict(counts)
    except Exception as e:
        print(f"Error during group and count in collection '{collection_name}': {e}")
        return {}

async def query_collection_with_filters(
    collection_name: str,
    filters: List[Dict[str, Any]],
    limit: int = 20,
    order_by_field: str = 'timestamp',
    order_by_direction: str = 'DESCENDING'
) -> List[Dict[str, Any]]:
    """
    Queries a Firestore collection with a list of filters.

    Args:
        collection_name: The name of the collection to query.
        filters: A list of filter dictionaries. Each dict should have 'field', 'op', and 'value'.
                 e.g., [{'field': 'api_name', 'op': '==', 'value': 'some_api'}]
        limit: The maximum number of documents to return.
        order_by_field: The field to order the results by.
        order_by_direction: The direction to order by ('ASCENDING' or 'DESCENDING').

    Returns:
        A list of document dictionaries.
    """
    if not db:
        print("Firestore client is not initialized. Cannot query collection.")
        return []

    try:
        query = db.collection(collection_name)

        for f in filters:
            field_filter = firestore.FieldFilter(f['field'], f['op'], f['value'])
            query = query.where(filter=field_filter)

        if order_by_field:
            direction = firestore.Query.DESCENDING if order_by_direction.upper() == 'DESCENDING' else firestore.Query.ASCENDING
            query = query.order_by(order_by_field, direction=direction)

        query = query.limit(limit)

        documents = []
        async for doc in query.stream():
            doc_data = doc.to_dict()
            # Ensure timestamp is JSON serializable
            if 'timestamp' in doc_data and isinstance(doc_data.get('timestamp'), datetime):
                doc_data['timestamp'] = doc_data['timestamp'].isoformat()
            documents.append(doc_data)
        print(f"Successfully queried {len(documents)} documents from '{collection_name}'.")
        return documents
    except Exception as e:
        print(f"Error querying collection '{collection_name}' from Firestore: {e}")
        return []