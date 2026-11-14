@testable import Aoi

enum Fixtures {
    // A small OpenAPI spec covering enums, nested lists, allOf, oneOf, path variables and bearer auth.
    static let spec = """
    openapi: 3.0.0
    info: {title: Library, version: "1"}
    servers:
      - url: https://library.test/api
    components:
      securitySchemes:
        bearer: {type: http, scheme: bearer}
      schemas:
        Base:
          type: object
          properties:
            name: {type: string}
            id: {type: integer}
    security:
      - bearer: []
    paths:
      /v1/books:
        post:
          summary: Add a book
          requestBody:
            content:
              application/json:
                schema:
                  type: object
                  required: [shelf, copies]
                  properties:
                    shelf:
                      type: string
                      description: Where the copies are kept
                      enum: [NORTH_WING, SOUTH_WING]
                    copies:
                      type: array
                      items:
                        type: object
                        required: [barcode]
                        properties:
                          barcode: {type: string}
                          lent: {type: boolean}
      /v1/books/{book_id}:
        get:
          summary: Get book
          parameters:
            - {name: book_id, in: path, required: true, schema: {type: string}}
      /v1/merged:
        post:
          requestBody:
            content:
              application/json:
                schema:
                  allOf:
                    - $ref: '#/components/schemas/Base'
                    - required: [extra]
                  properties:
                    extra: {type: string}
                  required: [name]
      /v1/choice:
        post:
          requestBody:
            content:
              application/json:
                schema:
                  oneOf:
                    - {type: string, enum: [A, B]}
                    - {type: string, enum: [C]}
    """

    static func collection() throws -> APICollection {
        try OpenAPIImporter(root: YAMLParser.parse(spec)).collection(fallbackName: "Library")
    }

    static func schema(_ path: String) throws -> BodySchema? {
        try collection().requests.first { $0.draft.url.hasSuffix(path) }?.bodySchema
    }

    struct MissingSchema: Error {}

    static func requiredSchema(_ path: String) throws -> BodySchema {
        guard let schema = try schema(path) else { throw MissingSchema() }
        return schema
    }
}
