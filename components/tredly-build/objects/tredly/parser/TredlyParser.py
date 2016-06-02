import os
import json
from jsonschema import validate, Draft4Validator, validators
from actions.destroy import *

class TredlyParser:
    def __init__(self,filePath):
        self.filePath = filePath

    def read(self):
        with open(self.filePath) as file:
            self.json = json.load(file)
        return self.json

    def validate(self):
        # make sure the tredlyfile matches this version
        tredlyBuildVersion = VERSION_NUMBER.split('.')
        compatibleWith = self.json['container']['compatibleWith'].split('.')
        if (tredlyBuildVersion[0] != compatibleWith[0]) or (tredlyBuildVersion[1] != compatibleWith[1]):
            e_error("Tredlyfile version " + self.json['container']['compatibleWith'] + " does not match tredly-build version " + tredlyBuildVersion[0] + '.' + tredlyBuildVersion[1] + '.0')
            exit(1)
        
        with open(os.path.abspath(os.path.join(os.path.dirname( __file__ ), builtins.tredlyJsonDirectory + '/tredlyfile.schema.json'))) as jsonSchema:
            schema = json.load(jsonSchema)

            DefaultValidatingDraft4Validator = extend_with_default(Draft4Validator)
            DefaultValidatingDraft4Validator(schema).validate(self.json)
        


def extend_with_default(validator_class):
    validate_properties = validator_class.VALIDATORS["properties"]

    def set_defaults(validator, properties, instance, schema):
        for property, subschema in properties.items():
            if "default" in subschema:
                instance.setdefault(property, subschema["default"])

        for error in validate_properties(
            validator, properties, instance, schema,
        ):
            yield error

    return validators.extend(
        validator_class, {"properties" : set_defaults},
    )