from ansible.errors import AnsibleError
from ansible.plugins.lookup import LookupBase

import shade


class LookupModule(LookupBase):

    def run(self, volume_names, variables=None, **kwargs):
        cloud = shade.openstack_cloud()
        volume_attributes = [
            "id",
            "name",
            "display_name",
            "size",
            "description",
        ]

        def get_volume(name_or_id):
            volume = cloud.get_volume(name_or_id)
            if not volume:
                raise AnsibleError(
                    "Could not find volume: {}".format(name_or_id))

            result = {}
            for attribute_name in volume_attributes:
                result[attribute_name] = getattr(volume, attribute_name)
            return result

        return [get_volume(volume_name) for volume_name in volume_names]
