from lightspeed_rag_content.metadata_processor import MetadataProcessor
from lightspeed_rag_content.document_processor import DocumentProcessor
from lightspeed_rag_content import utils


class CustomMetadataProcessor(MetadataProcessor):

    def __init__(self, url, hermetic_build=False):
        super().__init__(hermetic_build=hermetic_build)
        self.url = url

    def url_function(self, file_path: str) -> str:
        return self.url


if __name__ == "__main__":
    parser = utils.get_common_arg_parser()
    args = parser.parse_args()

    metadata_processor = CustomMetadataProcessor(
        "https://docs.example.com", hermetic_build=True
    )

    document_processor = DocumentProcessor(
        chunk_size=args.chunk,
        chunk_overlap=args.overlap,
        model_name=args.model_name,
        embeddings_model_dir=args.model_dir,
        num_workers=args.workers,
        vector_store_type=args.vector_store_type,
        doc_type=args.doc_type,
    )

    document_processor.process(args.folder, metadata=metadata_processor)
    document_processor.save(args.index, args.output)
