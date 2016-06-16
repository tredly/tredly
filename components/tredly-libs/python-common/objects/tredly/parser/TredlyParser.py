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

        # make sure the tredlyfile matches this version
        tredlyBuildVersion = VERSION_NUMBER.split('.')
        compatibleWith = self.json['container']['compatibleWith'].split('.')
        if (tredlyBuildVersion[0] != compatibleWith[0]) or (tredlyBuildVersion[1] != compatibleWith[1]):
            e_error("Tredlyfile version " + self.json['container']['compatibleWith'] + " does not match tredly-build version " + tredlyBuildVersion[0] + '.' + tredlyBuildVersion[1] + '.0')
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
            '''
            try:
                defaultValidatingDraft4Validator(schema).validate(self.json)
            except jsonschema.exceptions.ValidationError:
                for error in sorted(defaultValidatingDraft4Validator.iter_errors(self.json), key=str):
                    print(error.message)
                return False
            '''
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