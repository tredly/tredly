import os
import json
import builtins
import sys
import jsonschema

from includes.defines import *
from includes.util import *

class TredlyParser:
    def __init__(self,filePath):
        self.filePath = filePath

    # Action: Loads json from a given file
    #
    # Pre:
    # Post: self.json has been updated with the json from the file
    #
    # Params:
    #
    # Return: json object
    def read(self):
        with open(self.filePath) as file:
            self.json = json.load(file)
        return self.json

    # Action: Validate self.json against the given schema
    #
    # Pre:
    # Post:
    #
    # Params:
    #
    # Return: True if valid, False otherwise
    def validate(self):
        # if restrictTo is set then check against this version
        if ('restrictTo' in self.json['container']) and (self.json['container']['restrictTo'] is not None) and (len(self.json['container']['restrictTo']) > 0):
            # make sure the tredlyfile matches this version
            tredlyVersion = VERSION_NUMBER.split('.')
            restrictTo = self.json['container']['restrictTo'].split('.')
            if (tredlyVersion[0] != restrictTo[0]) or (tredlyVersion[1] != restrictTo[1]):
                e_error("Tredlyfile version " + self.json['container']['restrictTo'] + " is incompatible with tredly version " + tredlyVersion[0] + '.' + tredlyVersion[1] + '.x')
                e_error("Please update your Tredlyfile to match the version of this release (" + VERSION_NUMBER + ").")
                return False

        # open the schema and extend with the defaults
        with open(os.path.abspath(os.path.join(os.path.dirname( __file__ ), builtins.tredlyJsonDirectory + '/tredlyfile.schema.json'))) as jsonSchema:
            # load the schema
            schema = json.load(jsonSchema)

            # add defaults
            defaultValidatingDraft4Validator = extendWithDefaults(jsonschema.Draft4Validator)

            v = defaultValidatingDraft4Validator(schema)

            # print any error messages
            for error in sorted(v.iter_errors(self.json), key=lambda e: e.path):
                e_error(error.message)

            return defaultValidatingDraft4Validator(schema).is_valid(self.json)

        return True

# Action: use the json schema to populate defaults in json object
#
# Pre:
# Post:
#
# Params:
#
# Return:
def extendWithDefaults(validatorClass):
    validateProperties = validatorClass.VALIDATORS["properties"]

    # set the defaults
    def setDefaults(validator, properties, instance, schema):
        for property, subschema in properties.items():
            if "default" in subschema:
                instance.setdefault(property, subschema["default"])

        for error in validateProperties(
            validator, properties, instance, schema,
        ):
            yield error

    return jsonschema.validators.extend(
        validatorClass, {"properties" : setDefaults},
    )
