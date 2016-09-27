#--
# Copyright (c) 2012, Sebastian Tello
# All rights reserved.

# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#   * Redistributions of source code must retain the above copyright notice,
#     this list of conditions and the following disclaimer.
#   * Redistributions in binary form must reproduce the above copyright notice,
#     this list of conditions and the following disclaimer in the documentation
#     and/or other materials provided with the distribution.
#   * Neither the name of copyright holders nor the names of its contributors
#     may be used to endorse or promote products derived from this software
#     without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#--

import sys
import time
import os

from pysphere.resources import VimService_services as VI
from pysphere import VIException, VIApiException, FaultTypes
from pysphere import VITask, VIProperty, VIMor, MORTypes
from pysphere.vi_snapshot import VISnapshot

class VIVirtualMachine:

    def __init__(self, server, mor):
        self._server = server
        self._mor = mor
        self._root_snapshots = []
        self._snapshot_list = []
        self._disks = []
        self._files = {}
        self._devices = {}
        self.__current_snapshot = None
        self._resource_pool = None
        self.properties = None
        self._properties = {}
        self.__update_properties()
        self._mor_vm_task_collector = None
        #Define guest operation managers
        self._auth_mgr = None
        self._auth_obj = None
        self._file_mgr = None
        self._proc_mgr = None
        try:
            guest_op = VIProperty(self._server, self._server._do_service_content
                                                        .GuestOperationsManager)
            self._auth_mgr = guest_op.authManager._obj
            try:
                self._file_mgr = guest_op.fileManager._obj
            except AttributeError:
                #file manager not present
                pass
            try:
                #process manager not present
                self._proc_mgr = guest_op.processManager._obj
            except:
                pass
        except AttributeError:
            #guest operations not supported (since API 5.0)
            pass

    #-------------------#
    #-- POWER METHODS --#
    #-------------------#
    def power_on(self, sync_run=True, host=None):
        """Attemps to power on the VM. If @sync_run is True (default) waits for
        the task to finish, and returns (raises an exception if the task didn't
        succeed). If sync_run is set to False the task is started an a VITask
        instance is returned. You may additionally provided a managed object
        reference to a host where the VM should be powered on at."""
        try:
            request = VI.PowerOnVM_TaskRequestMsg()
            mor_vm = request.new__this(self._mor)
            mor_vm.set_attribute_type(self._mor.get_attribute_type())
            request.set_element__this(mor_vm)
            if host:
                mor_host = request.new_host(host)
                mor_host.set_attribute_type(host.get_attribute_type())
                request.set_element_host(mor_host)

            task = self._server._proxy.PowerOnVM_Task(request)._returnval
            vi_task = VITask(task, self._server)
            if sync_run:
                status = vi_task.wait_for_state([vi_task.STATE_SUCCESS,
                                                 vi_task.STATE_ERROR])
                if status == vi_task.STATE_ERROR:
                    raise VIException(vi_task.get_error_message(),
                                      FaultTypes.TASK_ERROR)
                return

            return vi_task

        except (VI.ZSI.FaultException), e:
            raise VIApiException(e)

    def power_off(self, sync_run=True):
        """Attemps to power off the VM. If @sync_run is True (default) waits for
        the task to finish, and returns (raises an exception if the task didn't
        succeed). If sync_run is set to False the task is started an a VITask
        instance is returned. """
        try:
            request = VI.PowerOffVM_TaskRequestMsg()
            mor_vm = request.new__this(self._mor)
            mor_vm.set_attribute_type(self._mor.get_attribute_type())
            request.set_element__this(mor_vm)

            task = self._server._proxy.PowerOffVM_Task(request)._returnval
            vi_task = VITask(task, self._server)
            if sync_run:
                status = vi_task.wait_for_state([vi_task.STATE_SUCCESS,
                                                 vi_task.STATE_ERROR])
                if status == vi_task.STATE_ERROR:
                    raise VIException(vi_task.get_error_message(),
                                      FaultTypes.TASK_ERROR)
                return

            return vi_task

        except (VI.ZSI.FaultException), e:
            raise VIApiException(e)

    def reset(self, sync_run=True):
        """Attempts to reset the VM. If @sync_run is True (default) waits for the
        task to finish, and returns (raises an exception if the task didn't
        succeed). If sync_run is set to False the task is started an a VITask
        instance is returned. """
        try:
            request = VI.ResetVM_TaskRequestMsg()
            mor_vm = request.new__this(self._mor)
            mor_vm.set_attribute_type(self._mor.get_attribute_type())
            request.set_element__this(mor_vm)

            task = self._server._proxy.ResetVM_Task(request)._returnval
            vi_task = VITask(task, self._server)
            if sync_run:
                status = vi_task.wait_for_state([vi_task.STATE_SUCCESS,
                                                 vi_task.STATE_ERROR])
                if status == vi_task.STATE_ERROR:
                    raise VIException(vi_task.get_error_message(),
                                      FaultTypes.TASK_ERROR)
                return

            return vi_task

        except (VI.ZSI.FaultException), e:
            raise VIApiException(e)

    def suspend(self, sync_run=True):
        """Attempts to suspend the VM (it must be powered on)"""
        try:
            request = VI.SuspendVM_TaskRequestMsg()
            mor_vm = request.new__this(self._mor)
            mor_vm.set_attribute_type(self._mor.get_attribute_type())
            request.set_element__this(mor_vm)

            task = self._server._proxy.SuspendVM_Task(request)._returnval
            vi_task = VITask(task, self._server)
            if sync_run:
                status = vi_task.wait_for_state([vi_task.STATE_SUCCESS,
                                                 vi_task.STATE_ERROR])
                if status == vi_task.STATE_ERROR:
                    raise VIException(vi_task.get_error_message(),
                                      FaultTypes.TASK_ERROR)
                return

            return vi_task

        except (VI.ZSI.FaultException), e:
            raise VIApiException(e)

    def get_status(self, basic_status=False):
        """Returns any of the status strings defined in VMPowerState:
        basic statuses:
            'POWERED ON', 'POWERED OFF', 'SUSPENDED', 'BLOCKED ON MSG'
        extended_statuses (only available for vCenter):
            'POWERING ON', 'POWERING OFF', 'SUSPENDING', 'RESETTING',
            'REVERTING TO SNAPSHOT', 'UNKNOWN'
        if basic_status is False (defautl) and the server is a vCenter, then
        one of the extended statuses might be returned.
        """
        #we can't check tasks in a VMWare Server or ESXi
        if not basic_status and self._server.get_api_type() == 'VirtualCenter':
            try:
                if not self._mor_vm_task_collector:
                    self.__create_pendant_task_collector()
            except VIApiException:
                basic_status = True

        #get the VM current power state, and messages blocking if any
        vi_power_states = {'poweredOn':VMPowerState.POWERED_ON,
                           'poweredOff': VMPowerState.POWERED_OFF,
                           'suspended': VMPowerState.SUSPENDED}

        power_state = None

        oc_vm_status_msg = self._server._get_object_properties(
                      self._mor,
                      property_names=['runtime.question', 'runtime.powerState']
                      )
        properties = oc_vm_status_msg.PropSet
        for prop in properties:
            if prop.Name == 'runtime.powerState':
                power_state = prop.Val
            if prop.Name == 'runtime.question':
                return VMPowerState.BLOCKED_ON_MSG

        #we can't check tasks in a VMWare Server
        if self._server.get_api_type() != 'VirtualCenter' or basic_status:
            return vi_power_states.get(power_state, VMPowerState.UNKNOWN)

        #on the other hand, get the current task running or queued for this VM
        oc_task_history = self._server._get_object_properties(
                      self._mor_vm_task_collector,
                      property_names=['latestPage']
                      )
        properties = oc_task_history.PropSet
        if len(properties) == 0:
            return vi_power_states.get(power_state, VMPowerState.UNKNOWN)
        for prop in properties:
            if prop.Name == 'latestPage':
                tasks_info_array = prop.Val.TaskInfo
                if len(tasks_info_array) == 0:
                    return vi_power_states.get(power_state,VMPowerState.UNKNOWN)
                for task_info in tasks_info_array:
                    desc = task_info.DescriptionId
                    if task_info.State in ['success', 'error']:
                        continue

                    if desc == 'VirtualMachine.powerOff' and power_state in [
                                                      'poweredOn', 'suspended']:
                        return VMPowerState.POWERING_OFF
                    if desc in ['VirtualMachine.revertToCurrentSnapshot',
                                'vm.Snapshot.revert']:
                        return VMPowerState.REVERTING_TO_SNAPSHOT
                    if desc == 'VirtualMachine.reset' and power_state in [
                                                      'poweredOn', 'suspended']:
                        return VMPowerState.RESETTING
                    if desc == 'VirtualMachine.suspend' and power_state in [
                                                                   'poweredOn']:
                        return VMPowerState.SUSPENDING
                    if desc in ['Drm.ExecuteVmPowerOnLRO',
                                'VirtualMachine.powerOn'] and power_state in [
                                                     'poweredOff', 'suspended']:
                        return VMPowerState.POWERING_ON
                return vi_power_states.get(power_state, VMPowerState.UNKNOWN)

    def get_question(self):
        """Returns a VMQuestion object with information about a question in this
        vm pending to be answered. None if the vm has no pending questions.
        """

        class VMQuestion(object):
            def __init__(self, vm, qprop):
                self._answered = False
                self._vm = vm
                self._qid = qprop.id
                self._text = qprop.text
                self._choices = [(ci.key, ci.label)
                                 for ci in qprop.choice.choiceInfo]
                self._default = getattr(qprop.choice, 'defaultIndex', None)

            def text(self):
                return self._text
            def choices(self):
                return self._choices[:]
            def default_choice(self):
                return self._choices[self._default]
            def answer(self, choice=None):
                if self._answered:
                    raise VIException("Question already answered",
                                      FaultTypes.INVALID_OPERATION)
                if choice is None and self._default is None:
                    raise VIException("No default choice available",
                                      FaultTypes.PARAMETER_ERROR)
                elif choice is not None and choice not in [i[0] for i
                                                              in self._choices]:
                    raise VIException("Invalid choice id",
                                      FaultTypes.PARAMETER_ERROR)
                elif choice is None:
                    choice = self.default_choice()[0]
                try:
                    request = VI.AnswerVMRequestMsg()
                    _this = request.new__this(self._vm._mor)
                    _this.set_attribute_type(self._vm._mor.get_attribute_type())
                    request.set_element__this(_this)
                    request.set_element_questionId(self._qid)
                    request.set_element_answerChoice(choice)
                    self._vm._server._proxy.AnswerVM(request)
                    self._answered = True
                except (VI.ZSI.FaultException), e:
                    raise VIApiException(e)

        self.__update_properties()
        if not hasattr(self.properties.runtime, "question"):
            return
        return VMQuestion(self, self.properties.runtime.question)


    def is_powering_off(self):
        """Returns True if the VM is being powered off"""
        return self.get_status() == VMPowerState.POWERING_OFF

    def is_powered_off(self):
        """Returns True if the VM is powered off"""
        return self.get_status() == VMPowerState.POWERED_OFF

    def is_powering_on(self):
        """Returns True if the VM is being powered on"""
        return self.get_status() == VMPowerState.POWERING_ON

    def is_powered_on(self):
        """Returns True if the VM is powered off"""
        return self.get_status() == VMPowerState.POWERED_ON

    def is_suspending(self):
        """Returns True if the VM is being suspended"""
        return self.get_status() == VMPowerState.SUSPENDING

    def is_suspended(self):
        """Returns True if the VM is suspended"""
        return self.get_status() == VMPowerState.SUSPENDED

    def is_resetting(self):
        """Returns True if the VM is being resetted"""
        return self.get_status() == VMPowerState.RESETTING

    def is_blocked_on_msg(self):
        """Returns True if the VM is blocked because of a question message"""
        return self.get_status() == VMPowerState.BLOCKED_ON_MSG

    def is_reverting(self):
        """Returns True if the VM is being reverted to a snapshot"""
        return self.get_status() == VMPowerState.REVERTING_TO_SNAPSHOT

    #-------------------------#
    #-- GUEST POWER METHODS --#
    #-------------------------#

    def reboot_guest(self):
        """Issues a command to the guest operating system asking it to perform
        a reboot. Returns immediately and does not wait for the guest operating
        system to complete the operation."""
        try:
            request = VI.RebootGuestRequestMsg()
            mor_vm = request.new__this(self._mor)
            mor_vm.set_attribute_type(self._mor.get_attribute_type())
            request.set_element__this(mor_vm)

            self._server._proxy.RebootGuest(request)

        except (VI.ZSI.FaultException), e:
            raise VIApiException(e)


    def shutdown_guest(self):
        """Issues a command to the guest operating system asking it to perform
        a clean shutdown of all services. Returns immediately and does not wait
        for the guest operating system to complete the operation. """
        try:
            request = VI.ShutdownGuestRequestMsg()
            mor_vm = request.new__this(self._mor)
            mor_vm.set_attribute_type(self._mor.get_attribute_type())
            request.set_element__this(mor_vm)

            self._server._proxy.ShutdownGuest(request)

        except (VI.ZSI.FaultException), e:
            raise VIApiException(e)

    def standby_guest(self):
        """Issues a command to the guest operating system asking it to prepare
        for a suspend operation. Returns immediately and does not wait for the
        guest operating system to complete the operation."""
        try:
            request = VI.StandbyGuestRequestMsg()
            mor_vm = request.new__this(self._mor)
            mor_vm.set_attribute_type(self._mor.get_attribute_type())
            request.set_element__this(mor_vm)

            self._server._proxy.StandbyGuest(request)

        except (VI.ZSI.FaultException), e:
            raise VIApiException(e)

    #--------------#
    #-- CLONE VM --#
    #--------------#
    def clone(self, name, sync_run=True, folder=None, resourcepool=None,
              datastore=None, host=None, power_on=True, template=False,
              snapshot=None, linked=False):
        """Clones this Virtual Machine
        @name: name of the new virtual machine
        @sync_run: if True (default) waits for the task to finish, and returns
            a VIVirtualMachine instance with the new VM (raises an exception if
        the task didn't succeed). If sync_run is set to False the task is
        started and a VITask instance is returned
        @folder: name of the folder that will contain the new VM, if not set
            the vm will be added to the folder the original VM belongs to
        @resourcepool: MOR of the resourcepool to be used for the new vm.
            If not set, it uses the same resourcepool than the original vm.
        @datastore: MOR of the datastore where the virtual machine
            should be located. If not specified, the current datastore is used.
        @host: MOR of the host where the virtual machine should be registered.
            IF not specified:
              * if resourcepool is not specified, current host is used.
              * if resourcepool is specified, and the target pool represents a
                stand-alone host, the host is used.
              * if resourcepool is specified, and the target pool represents a
                DRS-enabled cluster, a host selected by DRS is used.
              * if resource pool is specified and the target pool represents a
                cluster without DRS enabled, an InvalidArgument exception be
                thrown.
        @power_on: If the new VM will be powered on after being created. If
            template is set to True, this parameter is ignored.
        @template: Specifies whether or not the new virtual machine should be
            marked as a template.
        @snapshot: Snaphot MOR, or VISnaphost object, or snapshot name (if a
            name is given, then the first matching occurrence will be used).
            Is the snapshot reference from which to base the clone. If this
            parameter is set, the clone is based off of the snapshot point. This
            means that the newly created virtual machine will have the same
            configuration as the virtual machine at the time the snapshot was
            taken. If this parameter is not set then the clone is based off of
            the virtual machine's current configuration.
        @linked: If True (requires @snapshot to be set) creates a new child disk
            backing on the destination datastore. None of the virtual disk's
            existing files should be moved from their current locations.
            Note that in the case of a clone operation, this means that the
            original virtual machine's disks are now all being shared. This is
            only safe if the clone was taken from a snapshot point, because
            snapshot points are always read-only. Thus for a clone this option
            is only valid when cloning from a snapshot
        """
        try:
            #get the folder to create the VM
            folders = self._server._retrieve_properties_traversal(
                                         property_names=['name', 'childEntity'],
                                         obj_type=MORTypes.Folder)
            folder_mor = None
            for f in folders:
                fname = ""
                children = []
                for prop in f.PropSet:
                    if prop.Name == "name":
                        fname = prop.Val
                    elif prop.Name == "childEntity":
                        children = prop.Val.ManagedObjectReference
                if folder == fname or (not folder and self._mor in children):
                    folder_mor = f.Obj
                    break
            if not folder_mor and folder:
                raise VIException("Couldn't find folder %s" % folder,
                                  FaultTypes.OBJECT_NOT_FOUND)
            elif not folder_mor:
                raise VIException("Error locating current VM folder",
                                  FaultTypes.OBJECT_NOT_FOUND)

            request = VI.CloneVM_TaskRequestMsg()
            _this = request.new__this(self._mor)
            _this.set_attribute_type(self._mor.get_attribute_type())
            request.set_element__this(_this)
            request.set_element_folder(folder_mor)
            request.set_element_name(name)
            spec = request.new_spec()
            if template:
                spec.set_element_powerOn(False)
            else:
                spec.set_element_powerOn(power_on)
            location = spec.new_location()
            if resourcepool:
                if not VIMor.is_mor(resourcepool):
                    resourcepool = VIMor(resourcepool, MORTypes.ResourcePool)
                pool = location.new_pool(resourcepool)
                pool.set_attribute_type(resourcepool.get_attribute_type())
                location.set_element_pool(pool)
            if datastore:
                if not VIMor.is_mor(datastore):
                    datastore = VIMor(datastore, MORTypes.Datastore)
                ds = location.new_datastore(datastore)
                ds.set_attribute_type(datastore.get_attribute_type())
                location.set_element_datastore(ds)
            if host:
                if not VIMor.is_mor(host):
                    host = VIMor(host, MORTypes.HostSystem)
                hs = location.new_host(host)
                hs.set_attribute_type(host.get_attribute_type())
                location.set_element_host(hs)
            if snapshot:
                sn_mor = None
                if VIMor.is_mor(snapshot):
                    sn_mor = snapshot
                elif isinstance(snapshot, VISnapshot):
                    sn_mor = snapshot._mor
                elif isinstance(snapshot, basestring):
                    for sn in self.get_snapshots():
                        if sn.get_name() == snapshot:
                            sn_mor = sn._mor
                            break
                if not sn_mor:
                    raise VIException("Could not find snapshot '%s'" % snapshot,
                                      FaultTypes.OBJECT_NOT_FOUND)
                snapshot = spec.new_snapshot(sn_mor)
                snapshot.set_attribute_type(sn_mor.get_attribute_type())
                spec.set_element_snapshot(snapshot)

            if linked and snapshot:
                location.set_element_diskMoveType("createNewChildDiskBacking")

            spec.set_element_location(location)
            spec.set_element_template(template)
            request.set_element_spec(spec)
            task = self._server._proxy.CloneVM_Task(request)._returnval
            vi_task = VITask(task, self._server)
            if sync_run:
                status = vi_task.wait_for_state([vi_task.STATE_SUCCESS,
                                                 vi_task.STATE_ERROR])
                if status == vi_task.STATE_ERROR:
                    raise VIException(vi_task.get_error_message(),
                                      FaultTypes.TASK_ERROR)
                return VIVirtualMachine(self._server, vi_task.get_result()._obj)

            return vi_task

        except (VI.ZSI.FaultException), e:
            raise VIApiException(e)

    #-------------#
    #-- VMOTION --#
    #-------------#
    def migrate(self, sync_run=True, priority='default', resource_pool=None,
                host=None, state=None):
        """
        Cold or Hot migrates this VM to a new host or resource pool.
        @sync_run: If True (default) waits for the task to finish, and returns
            (raises an exception if the task didn't succeed). If False the task
            is started an a VITask instance is returned.
        @priority: either 'default', 'high', or 'low': priority of the task that
            moves the vm. Note this priority can affect both the source and
            target hosts.
        @resource_pool: The target resource pool for the virtual machine. If the
            pool parameter is left unset, the virtual machine's current pool is
            used as the target pool.
        @host: The target host to which the virtual machine is intended to
            migrate. The host parameter may be left unset if the compute
            resource associated with the target pool represents a stand-alone
            host or a DRS-enabled cluster. In the former case the stand-alone
            host is used as the target host. In the latter case, the DRS system
            selects an appropriate target host from the cluster.
        @state: If specified, the virtual machine migrates only if its state
            matches the specified state.
        """
        try:
            if priority not in ['default', 'low', 'high']:
                raise VIException("priority must be either 'default', 'low', "
                                  "or 'high'.", FaultTypes.PARAMETER_ERROR)
            if state and state not in [None, VMPowerState.POWERED_ON,
                              VMPowerState.POWERED_OFF, VMPowerState.SUSPENDED]:
                raise VIException("state, if set, must be either '%s', '%s', "
                                  "or '%s'." % (VMPowerState.POWERED_ON,
                                                VMPowerState.POWERED_OFF,
                                                VMPowerState.SUSPENDED),
                                   FaultTypes.PARAMETER_ERROR)

            request = VI.MigrateVM_TaskRequestMsg()
            _this = request.new__this(self._mor)
            _this.set_attribute_type(self._mor.get_attribute_type())
            request.set_element__this(_this)
            if resource_pool:
                if not VIMor.is_mor(resource_pool):
                    resource_pool = VIMor(resource_pool, MORTypes.ResourcePool)
                pool = request.new_pool(resource_pool)
                pool.set_attribute_type(resource_pool.get_attribute_type())
                request.set_element_pool(pool)
            if host:
                if not VIMor.is_mor(host):
                    host = VIMor(host, MORTypes.HostSystem)
                mor_host = request.new_host(host)
                mor_host.set_attribute_type(host.get_attribute_type())
                request.set_element_host(mor_host)
            request.set_element_priority(priority + "Priority")
            if state:
                states = {VMPowerState.POWERED_ON:  'poweredOn',
                          VMPowerState.POWERED_OFF: 'poweredOff',
                          VMPowerState.SUSPENDED:   'suspended'}
                request.set_element_state(states[state])

            task = self._server._proxy.MigrateVM_Task(request)._returnval
            vi_task = VITask(task, self._server)
            if sync_run:
                status = vi_task.wait_for_state([vi_task.STATE_SUCCESS,
                                                 vi_task.STATE_ERROR])
                if status == vi_task.STATE_ERROR:
                    raise VIException(vi_task.get_error_message(),
                                      FaultTypes.TASK_ERROR)
                return

            return vi_task
        except (VI.ZSI.FaultException), e:
            raise VIApiException(e)

    def relocate(self, sync_run=True, priority='default', datastore=None,
                 resource_pool=None, host=None, transform=None):
        """
        Cold or Hot relocates this virtual machine's virtual disks to a new
        datastore.
        @sync_run: If True (default) waits for the task to finish, and returns
          (raises an exception if the task didn't succeed). If False the task is
          started an a VITask instance is returned.
        @priority: either 'default', 'high', or 'low': priority of the task that
          moves the vm. Note this priority can affect both the source and target
          hosts.
        @datastore: The target datastore to which the virtual machine's virtual
          disks are intended to migrate.
        @resource_pool: The resource pool to which this virtual machine should
          be attached. If the argument is not supplied, the current resource
          pool of virtual machine is used.
        @host: The target host for the virtual machine. If not specified,
          * if resource pool is not specified, current host is used.
          * if resource pool is specified, and the target pool represents a
            stand-alone host, the host is used.
          * if resource pool is specified, and the target pool represents a
            DRS-enabled cluster, a host selected by DRS is used.
          * if resource pool is specified and the target pool represents a
            cluster without DRS enabled, an InvalidArgument exception be thrown.
        @transform: If specified, the virtual machine's virtual disks are
          transformed to the datastore using the specificed method; must be
          either 'flat' or 'sparse'.
        """
        try:
            if priority not in ['default', 'low', 'high']:
                raise VIException(
                        "priority must be either 'default', 'low', or 'high'.",
                        FaultTypes.PARAMETER_ERROR)
            if transform and transform not in [None, 'flat', 'sparse']:
                raise VIException(
                        "transform, if set, must be either '%s' or '%s'."
                        % ('flat', 'sparse'), FaultTypes.PARAMETER_ERROR)
            request = VI.RelocateVM_TaskRequestMsg()
            _this = request.new__this(self._mor)
            _this.set_attribute_type(self._mor.get_attribute_type())
            request.set_element__this(_this)
            spec = request.new_spec()
            if datastore:
                if not VIMor.is_mor(datastore):
                    ds = VIMor(datastore, MORTypes.Datastore)
                    datastore = spec.new_datastore(ds)
                    datastore.set_attribute_type(ds.get_attribute_type())
                spec.set_element_datastore(datastore)
            if resource_pool:
                if not VIMor.is_mor(resource_pool):
                    rp = VIMor(resource_pool, MORTypes.ResourcePool)
                    resource_pool = spec.new_pool(rp)
                    resource_pool.set_attribute_type(rp.get_attribute_type())
                spec.set_element_pool(resource_pool)
            if host:
                if not VIMor.is_mor(host):
                    h = VIMor(host, MORTypes.HostSystem)
                    host = spec.new_host(h)
                    host.set_attribute_type(h.get_attribute_type())
                spec.set_element_host(host)
            if transform:
                spec.set_element_transform(transform)
            request.set_element_priority(priority + "Priority")
            request.set_element_spec(spec)
            task = self._server._proxy.RelocateVM_Task(request)._returnval
            vi_task = VITask(task, self._server)
            if sync_run:
                status = vi_task.wait_for_state([vi_task.STATE_SUCCESS,
                                                 vi_task.STATE_ERROR])
                if status == vi_task.STATE_ERROR:
                    raise VIException(vi_task.get_error_message(),
                                      FaultTypes.TASK_ERROR)
                return
            return vi_task
        except (VI.ZSI.FaultException), e:
            raise VIApiException(e)

    #----------------------#
    #-- SNAPSHOT METHODS --#
    #----------------------#

    def get_snapshots(self):
        """Returns a list of VISnapshot instances of this VM"""
        return self._snapshot_list[:]

    def get_current_snapshot_name(self):
        """Returns the name of the current snapshot (if any)."""
        self.__update_properties()
        if not self.__current_snapshot:
            return None
        for snap in self._snapshot_list:
            if str(self.__current_snapshot) == str(snap._mor):
                return snap._name
        return None

    def revert_to_snapshot(self, sync_run=True, host=None):
        """Attemps to revert the VM to the current snapshot. If @sync_run is
        True (default) waits for the task to finish, and returns (raises an
        exception if the task didn't succeed). If sync_run is set to False the
        task is started an a VITask instance is returned. You may additionally
        provided a managed object reference to a host where the VM should be
        reverted at."""
        try:
            request = VI.RevertToCurrentSnapshot_TaskRequestMsg()
            mor_vm = request.new__this(self._mor)
            mor_vm.set_attribute_type(self._mor.get_attribute_type())
            request.set_element__this(mor_vm)
            if host:
                mor_host = request.new_host(host)
                mor_host.set_attribute_type(host.get_attribute_type())
                request.set_element_host(mor_host)

            task = self._server._proxy.RevertToCurrentSnapshot_Task(request) \
                                                                    ._returnval
            vi_task = VITask(task, self._server)
            if sync_run:
                status = vi_task.wait_for_state([vi_task.STATE_SUCCESS,
                                                 vi_task.STATE_ERROR])
                if status == vi_task.STATE_ERROR:
                    raise VIException(vi_task.get_error_message(),
                                      FaultTypes.TASK_ERROR)
                return

            return vi_task

        except (VI.ZSI.FaultException), e:
            raise VIApiException(e)

    def revert_to_named_snapshot(self, name, sync_run=True, host=None):
        """Attemps to revert the VM to the snapshot of the given name (the first
        match found). If @sync_run is True (default) waits for the task to
        finish, and returns (raises an exception if the task didn't succeed).
        If sync_run is set to False the task is started an a VITask instance is
        returned. You may additionally provided a managed object reference to a
        host where the VM should be reverted at."""

        mor = None
        for snap in self._snapshot_list:
            if snap._name == name:
                mor = snap._mor
                break
        if not mor:
            raise VIException("Could not find snapshot '%s'" % name,
                              FaultTypes.OBJECT_NOT_FOUND)

        try:
            request = VI.RevertToSnapshot_TaskRequestMsg()

            mor_snap = request.new__this(mor)
            mor_snap.set_attribute_type(mor.get_attribute_type())
            request.set_element__this(mor_snap)
            if host:
                mor_host = request.new_host(host)
                mor_host.set_attribute_type(host.get_attribute_type())
                request.set_element_host(mor_host)

            task = self._server._proxy.RevertToSnapshot_Task(request)._returnval
            vi_task = VITask(task, self._server)
            if sync_run:
                status = vi_task.wait_for_state([vi_task.STATE_SUCCESS,
                                                 vi_task.STATE_ERROR])
                if status == vi_task.STATE_ERROR:
                    raise VIException(vi_task.get_error_message(),
                                      FaultTypes.TASK_ERROR)
                return

            return vi_task

        except (VI.ZSI.FaultException), e:
            raise VIApiException(e)

    def revert_to_path(self, path, index=0, sync_run=True, host=None):
        """Attemps to revert the VM to the snapshot of the given path and index
        (to disambiguate among snapshots with the same path, default 0)
        If @sync_run is True (default) waits for the task to finish, and returns
        (raises an exception if the task didn't succeed).
        If sync_run is set to False the task is started an a VITask instance is
        returned. You may additionally provided a managed object reference to a
        host where the VM should be reverted at."""

        mor = None
        for snap in self._snapshot_list:
            if snap.get_path() == path and snap._index == index:
                mor = snap._mor
                break
        if not mor:
            raise VIException("Couldn't find snapshot with path '%s' (index %d)"
                              % (path, index), FaultTypes.OBJECT_NOT_FOUND)

        try:
            request = VI.RevertToSnapshot_TaskRequestMsg()

            mor_snap = request.new__this(mor)
            mor_snap.set_attribute_type(mor.get_attribute_type())
            request.set_element__this(mor_snap)
            if host:
                mor_host = request.new_host(host)
                mor_host.set_attribute_type(host.get_attribute_type())
                request.set_element_host(mor_host)

            task = self._server._proxy.RevertToSnapshot_Task(request)._returnval
            vi_task = VITask(task, self._server)
            if sync_run:
                status = vi_task.wait_for_state([vi_task.STATE_SUCCESS,
                                                 vi_task.STATE_ERROR])
                if status == vi_task.STATE_ERROR:
                    raise VIException(vi_task.get_error_message(),
                                      FaultTypes.TASK_ERROR)
                return

            return vi_task

        except (VI.ZSI.FaultException), e:
            raise VIApiException(e)

    def create_snapshot(self, name, sync_run=True, description=None,
                        memory=True, quiesce=True):
        """
        Takes a snapshot of this VM
        @sync_run: if True (default) waits for the task to finish, and returns
            (raises an exception if the task didn't succeed). If False the task
            is started an a VITask instance is returned.
        @description: A description for this snapshot. If omitted, a default
            description may be provided.
        @memory: If True, a dump of the internal state of the virtual machine
            (basically a memory dump) is included in the snapshot. Memory
            snapshots consume time and resources, and thus take longer to
            create. When set to FALSE, the power state of the snapshot is set to
            powered off.
        @quiesce: If True and the virtual machine is powered on when the
            snapshot is taken, VMware Tools is used to quiesce the file system
            in the virtual machine. This assures that a disk snapshot represents
            a consistent state of the guest file systems. If the virtual machine
            is powered off or VMware Tools are not available, the quiesce flag
            is ignored.
        """
        try:
            request = VI.CreateSnapshot_TaskRequestMsg()
            mor_vm = request.new__this  (self._mor)
            mor_vm.set_attribute_type(self._mor.get_attribute_type())
            request.set_element__this(mor_vm)
            request.set_element_name(name)
            if description:
                request.set_element_description(description)
            request.set_element_memory(memory)
            request.set_element_quiesce(quiesce)

            task = self._server._proxy.CreateSnapshot_Task(request)._returnval
            vi_task = VITask(task, self._server)
            if sync_run:
                status = vi_task.wait_for_state([vi_task.STATE_SUCCESS,
                                                 vi_task.STATE_ERROR])
                self.refresh_snapshot_list()
                if status == vi_task.STATE_ERROR:
                    raise VIException(vi_task.get_error_message(),
                                      FaultTypes.TASK_ERROR)
                return

            return vi_task

        except (VI.ZSI.FaultException), e:
            raise VIApiException(e)

    def delete_current_snapshot(self, remove_children=False, sync_run=True):
        """Removes the current snapshot. If @remove_children is True, removes
        all the snapshots in the subtree as well. If @sync_run is True (default)
        waits for the task to finish, and returns (raises an exception if the
        task didn't succeed). If sync_run is set to False the task is started a
        VITask instance is returned."""
        self.refresh_snapshot_list()
        if not self.__current_snapshot:
            raise VIException("There is no current snapshot",
                              FaultTypes.OBJECT_NOT_FOUND)

        return self.__delete_snapshot(self.__current_snapshot, remove_children,
                                                                       sync_run)

    def delete_named_snapshot(self, name, remove_children=False, sync_run=True):
        """Removes the first snapshot found in this VM named after @name
        If @remove_children is True, removes all the snapshots in the subtree as
        well. If @sync_run is True (default) waits for the task to finish, and
        returns (raises an exception if the task didn't succeed). If sync_run is
        set to False the task is started an a VITask instance is returned."""

        mor = None
        for snap in self._snapshot_list:
            if snap._name == name:
                mor = snap._mor
                break
        if mor is None:
            raise VIException("Could not find snapshot '%s'" % name,
                              FaultTypes.OBJECT_NOT_FOUND)

        return self.__delete_snapshot(mor, remove_children, sync_run)


    def delete_snapshot_by_path(self, path, index=0, remove_children=False,
                                                                 sync_run=True):
        """Removes the VM snapshot of the given path and index (to disambiguate
        among snapshots with the same path, default 0). If @remove_children is
        True, removes all the snapshots in the subtree as well. If @sync_run is
        True (default) waits for the task to finish,and returns (raises an
        exception if the task didn't succeed). If sync_run is set to False the
        task is started an a VITask instance is returned.
        """

        mor = None
        for snap in self._snapshot_list:
            if snap.get_path() == path and snap._index == index:
                mor = snap._mor
                break
        if not mor:
            raise VIException("Couldn't find snapshot with path '%s' (index %d)"
                              % (path, index), FaultTypes.OBJECT_NOT_FOUND)

        self.__delete_snapshot(mor, remove_children, sync_run)


    def refresh_snapshot_list(self):
        """Refreshes the internal list of snapshots of this VM"""
        self.__update_properties()

    #--------------------------#
    #-- VMWARE TOOLS METHODS --#
    #--------------------------#

    def upgrade_tools(self, sync_run=True, params=None):
        """Attemps to upgrade the VMWare tools in the guest.
        If @sync_run is True (default) waits for the task to finish, and returns
        (raises an exception if the task didn't succeed)
        If sync_run is set to False the task is started an a VITask instance is
        returned.
        You may additionally provided a string (@params) with parameters to the
        tool upgrade executable."""
        try:
            request = VI.UpgradeTools_TaskRequestMsg()
            mor_vm = request.new__this(self._mor)
            mor_vm.set_attribute_type(self._mor.get_attribute_type())
            request.set_element__this(mor_vm)
            if params:
                request.set_element_installerOptions(str(params))

            task = self._server._proxy.UpgradeTools_Task(request)._returnval
            vi_task = VITask(task, self._server)
            if sync_run:
                status = vi_task.wait_for_state([vi_task.STATE_SUCCESS,
                                                 vi_task.STATE_ERROR])
                if status == vi_task.STATE_ERROR:
                    raise VIException(vi_task.get_error_message(),
                                      FaultTypes.TASK_ERROR)
                return

            return vi_task

        except (VI.ZSI.FaultException), e:
            raise VIApiException(e)

    def get_tools_status(self):
        """Returns any of the status described in class ToolsStatus.
        'NOT INSTALLED': VMware Tools has never been installed or has not run
                         in the virtual machine.
        'NOT RUNNING': VMware Tools is not running.
        'RUNNING': VMware Tools is running and the version is current.
        'RUNNING OLD': VMware Tools is running, but the version is not current.
        'UNKNOWN': Couldn't obtain the status of the VMwareTools.
        """

        statuses = {'toolsNotInstalled':ToolsStatus.NOT_INSTALLED,
                    'toolsNotRunning':ToolsStatus.NOT_RUNNING,
                    'toolsOk':ToolsStatus.RUNNING,
                    'toolsOld':ToolsStatus.RUNNING_OLD}

        oc = self._server._get_object_properties(self._mor,
                                           property_names=['guest.toolsStatus'])
        if not hasattr(oc, 'PropSet'):
            return ToolsStatus.UNKNOWN
        prop_set = oc.PropSet
        if len(prop_set) == 0:
            return ToolsStatus.UNKNOWN
        for prop in prop_set:
            if prop.Name == 'guest.toolsStatus':
                return statuses.get(prop.Val, ToolsStatus.UNKNOWN)


    def wait_for_tools(self, timeout=15):
        """Waits for the VMWare tools to be running in the guest. Or for the
        timeout in seconds to expire. If timed out a VIException is thrown"""
        timeout = abs(int(timeout))
        start_time = time.time()
        while True:
            cur_state = self.get_tools_status()
            if cur_state in [ToolsStatus.RUNNING, ToolsStatus.RUNNING_OLD]:
                return True

            if (time.time() - start_time) > timeout:
                raise VIException(
                              "Timed out waiting for VMware Tools to be ready.",
                              FaultTypes.TIME_OUT)
            time.sleep(1.5)

    #--------------------------#
    #-- GUEST AUTHENTICATION --#
    #--------------------------#
    def login_in_guest(self, user, password):
        """Authenticates in the guest with the acquired credentials for use in
        subsequent guest operation calls."""
        auth = VI.ns0.NamePasswordAuthentication_Def("NameAndPwd").pyclass()
        auth.set_element_interactiveSession(False)
        auth.set_element_username(user)
        auth.set_element_password(password)
        self.__validate_authentication(auth)
        self._auth_obj = auth

    #------------------------#
    #-- GUEST FILE METHODS --#
    #------------------------#

    def make_directory(self, path, create_parents=True):
        """
        Creates a directory in the guest OS
          * path [string]: The complete path to the directory to be created.
          * create_parents [bool]: Whether any parent directories are to be
                                   created. Default: True
        """
        if not self._file_mgr:
            raise VIException("Files operations not supported on this server",
                              FaultTypes.NOT_SUPPORTED)
        if not self._auth_obj:
            raise VIException("You must call first login_in_guest",
                              FaultTypes.INVALID_OPERATION)
        try:
            request = VI.MakeDirectoryInGuestRequestMsg()
            _this = request.new__this(self._file_mgr)
            _this.set_attribute_type(self._file_mgr.get_attribute_type())
            request.set_element__this(_this)
            vm = request.new_vm(self._mor)
            vm.set_attribute_type(self._mor.get_attribute_type())
            request.set_element_vm(vm)
            request.set_element_auth(self._auth_obj)
            request.set_element_directoryPath(path)
            request.set_element_createParentDirectories(create_parents)

            self._server._proxy.MakeDirectoryInGuest(request)
        except (VI.ZSI.FaultException), e:
            raise VIApiException(e)

    def move_directory(self, src_path, dst_path):
        """
        Moves or renames a directory in the guest.
          * src_path [string]: The complete path to the directory to be moved.
          * dst_path [string]: The complete path to the where the directory is
                               moved or its new name. It cannot be a path to an
                               existing directory or an existing file.
        """
        if not self._file_mgr:
            raise VIException("Files operations not supported on this server",
                              FaultTypes.NOT_SUPPORTED)
        if not self._auth_obj:
            raise VIException("You must call first login_in_guest",
                              FaultTypes.INVALID_OPERATION)
        try:
            request = VI.MoveDirectoryInGuestRequestMsg()
            _this = request.new__this(self._file_mgr)
            _this.set_attribute_type(self._file_mgr.get_attribute_type())
            request.set_element__this(_this)
            vm = request.new_vm(self._mor)
            vm.set_attribute_type(self._mor.get_attribute_type())
            request.set_element_vm(vm)
            request.set_element_auth(self._auth_obj)
            request.set_element_srcDirectoryPath(src_path)
            request.set_element_dstDirectoryPath(dst_path)

            self._server._proxy.MoveDirectoryInGuest(request)
        except (VI.ZSI.FaultException), e:
            raise VIApiException(e)

    def delete_directory(self, path, recursive):
        """
        Deletes a directory in the guest OS.
          * path [string]: The complete path to the directory to be deleted.
          * recursive [bool]: If true, all subdirectories are also deleted.
                              If false, the directory must be empty for the
                              operation to succeed.
        """
        if not self._file_mgr:
            raise VIException("Files operations not supported on this server",
                              FaultTypes.NOT_SUPPORTED)
        if not self._auth_obj:
            raise VIException("You must call first login_in_guest",
                              FaultTypes.INVALID_OPERATION)
        try:
            request = VI.DeleteDirectoryInGuestRequestMsg()
            _this = request.new__this(self._file_mgr)
            _this.set_attribute_type(self._file_mgr.get_attribute_type())
            request.set_element__this(_this)
            vm = request.new_vm(self._mor)
            vm.set_attribute_type(self._mor.get_attribute_type())
            request.set_element_vm(vm)
            request.set_element_auth(self._auth_obj)
            request.set_element_directoryPath(path)
            request.set_element_recursive(recursive)

            self._server._proxy.DeleteDirectoryInGuest(request)
        except (VI.ZSI.FaultException), e:
            raise VIApiException(e)

    def list_files(self, path, match_pattern=None):
        """
        Returns information about files or directories in the guest.
          * path [string]: The complete path to the directory or file to query.
          * match_pattern[string]: A filter for the return values. Match
          patterns are specified using perl-compatible regular expressions.
          If match_pattern isn't set, then the pattern '.*' is used.

        Returns a list of dictionaries with these keys:
          * path [string]: The complete path to the file
          * size [long]: The file size in bytes
          * type [string]: 'directory', 'file', or 'symlink'

        """
        if not self._file_mgr:
            raise VIException("Files operations not supported on this server",
                              FaultTypes.NOT_SUPPORTED)
        if not self._auth_obj:
            raise VIException("You must call first login_in_guest",
                              FaultTypes.INVALID_OPERATION)
        def ListFilesInGuest(path, match_pattern, index, max_results):
            try:
                request = VI.ListFilesInGuestRequestMsg()
                _this = request.new__this(self._file_mgr)
                _this.set_attribute_type(self._file_mgr.get_attribute_type())
                request.set_element__this(_this)
                vm = request.new_vm(self._mor)
                vm.set_attribute_type(self._mor.get_attribute_type())
                request.set_element_vm(vm)
                request.set_element_auth(self._auth_obj)
                request.set_element_filePath(path)
                if match_pattern:
                    request.set_element_matchPattern(match_pattern)
                if index:
                    request.set_element_index(index)
                if max_results:
                    request.set_element_maxResults(max_results)
                finfo = self._server._proxy.ListFilesInGuest(request)._returnval
                ret = []
                for f in getattr(finfo, "Files", []):
                    ret.append({'path':f.Path,
                                'size':f.Size,
                                'type':f.Type})
                return ret, finfo.Remaining
            except (VI.ZSI.FaultException), e:
                raise VIApiException(e)

        file_set, remaining = ListFilesInGuest(path, match_pattern, None, None)
        if remaining:
            file_set.extend(ListFilesInGuest(path, match_pattern,
                                            len(file_set), remaining)[0])

        return file_set

    def get_file(self, guest_path, local_path, overwrite=False):
        """
        Initiates an operation to transfer a file from the guest.
          * guest_path [string]: The complete path to the file inside the guest
                                that has to be transferred to the client. It
                                cannot be a path to a directory or a sym link.
          * local_path [string]: The path to the local file to be created
        """
        if not self._file_mgr:
            raise VIException("Files operations not supported on this server",
                              FaultTypes.NOT_SUPPORTED)
        if not self._auth_obj:
            raise VIException("You must call first login_in_guest",
                              FaultTypes.INVALID_OPERATION)
        if os.path.exists(local_path) and not overwrite:
            raise VIException("Local file already exists",
                              FaultTypes.PARAMETER_ERROR)

        from urlparse import urlparse

        try:
            request = VI.InitiateFileTransferFromGuestRequestMsg()
            _this = request.new__this(self._file_mgr)
            _this.set_attribute_type(self._file_mgr.get_attribute_type())
            request.set_element__this(_this)
            vm = request.new_vm(self._mor)
            vm.set_attribute_type(self._mor.get_attribute_type())
            request.set_element_vm(vm)
            request.set_element_auth(self._auth_obj)
            request.set_element_guestFilePath(guest_path)


            url = self._server._proxy.InitiateFileTransferFromGuest(request
                                                                )._returnval.Url
            url = url.replace("*", urlparse(self._server._proxy.binding.url
                                                                     ).hostname)
            if sys.version_info >= (2, 6):
                import urllib2
                req = urllib2.Request(url)
                r = urllib2.urlopen(req)

                CHUNK = 16 * 1024
                fd = open(local_path, "wb")
                while True:
                    chunk = r.read(CHUNK)
                    if not chunk: break
                    fd.write(chunk)
                fd.close()
            else:
                import urllib
                #I was getting a SSL Protocol error executing this on
                #python 2.6, but not with 2.5
                urllib.urlretrieve(url, local_path)

        except (VI.ZSI.FaultException), e:
            raise VIApiException(e)

    def send_file(self, local_path, guest_path, overwrite=False):
        """
        Initiates an operation to transfer a file to the guest.
          * local_path [string]: The path to the local file to be sent
          * guest_path [string]: The complete destination path in the guest to
                                 transfer the file from the client. It cannot be
                                 a path to a directory or a symbolic link.
          * overwrite [bool]: Default False, if True the destination file is
                              clobbered.
        """
        if not self._file_mgr:
            raise VIException("Files operations not supported on this server",
                              FaultTypes.NOT_SUPPORTED)
        if not self._auth_obj:
            raise VIException("You must call first login_in_guest",
                              FaultTypes.INVALID_OPERATION)
        import urllib2
        from urlparse import urlparse

        if not os.path.isfile(local_path):
            raise VIException("local_path is not a file or does not exists.",
                              FaultTypes.PARAMETER_ERROR)
        fd = open(local_path, "rb")
        content = fd.read()
        fd.close()

        try:
            request = VI.InitiateFileTransferToGuestRequestMsg()
            _this = request.new__this(self._file_mgr)
            _this.set_attribute_type(self._file_mgr.get_attribute_type())
            request.set_element__this(_this)
            vm = request.new_vm(self._mor)
            vm.set_attribute_type(self._mor.get_attribute_type())
            request.set_element_vm(vm)
            request.set_element_auth(self._auth_obj)
            request.set_element_guestFilePath(guest_path)
            request.set_element_overwrite(overwrite)
            request.set_element_fileSize(len(content))
            request.set_element_fileAttributes(request.new_fileAttributes())

            url = self._server._proxy.InitiateFileTransferToGuest(request
                                                                )._returnval

            url = url.replace("*", urlparse(self._server._proxy.binding.url
                                                                     ).hostname)
            opener = urllib2.build_opener(urllib2.HTTPHandler)
            request = urllib2.Request(url, data=content)
            request.get_method = lambda: 'PUT'
            resp = opener.open(request)
            if not resp.code == 200:
                raise VIException("File could not be send",
                                  FaultTypes.TASK_ERROR)
        except (VI.ZSI.FaultException), e:
            raise VIApiException(e)

    def move_file(self, src_path, dst_path, overwrite=False):
        """
        Renames a file in the guest.
          * src_path [string]: The complete path to the original file or
                               symbolic link to be moved.
          * dst_path [string]: The complete path to the where the file is
                               renamed. It cannot be a path to an existing
                               directory.
          * overwrite [bool]: Default False, if True the destination file is
                              clobbered.
        """
        if not self._file_mgr:
            raise VIException("Files operations not supported on this server",
                              FaultTypes.NOT_SUPPORTED)
        if not self._auth_obj:
            raise VIException("You must call first login_in_guest",
                              FaultTypes.INVALID_OPERATION)
        try:
            request = VI.MoveFileInGuestRequestMsg()
            _this = request.new__this(self._file_mgr)
            _this.set_attribute_type(self._file_mgr.get_attribute_type())
            request.set_element__this(_this)
            vm = request.new_vm(self._mor)
            vm.set_attribute_type(self._mor.get_attribute_type())
            request.set_element_vm(vm)
            request.set_element_auth(self._auth_obj)
            request.set_element_srcFilePath(src_path)
            request.set_element_dstFilePath(dst_path)
            request.set_element_overwrite(overwrite)
            self._server._proxy.MoveFileInGuest(request)
        except (VI.ZSI.FaultException), e:
            raise VIApiException(e)

    def delete_file(self, path):
        """
        Deletes a file in the guest OS
          * path [string]: The complete path to the file to be deleted.
        """
        if not self._file_mgr:
            raise VIException("Files operations not supported on this server",
                              FaultTypes.NOT_SUPPORTED)
        if not self._auth_obj:
            raise VIException("You must call first login_in_guest",
                              FaultTypes.INVALID_OPERATION)
        try:
            request = VI.DeleteFileInGuestRequestMsg()
            _this = request.new__this(self._file_mgr)
            _this.set_attribute_type(self._file_mgr.get_attribute_type())
            request.set_element__this(_this)
            vm = request.new_vm(self._mor)
            vm.set_attribute_type(self._mor.get_attribute_type())
            request.set_element_vm(vm)
            request.set_element_auth(self._auth_obj)
            request.set_element_filePath(path)
            self._server._proxy.DeleteFileInGuest(request)
        except (VI.ZSI.FaultException), e:
            raise VIApiException(e)

    #---------------------------#
    #-- GUEST PROCESS METHODS --#
    #---------------------------#

    def list_processes(self):
        """
        List the processes running in the guest operating system, plus those
        started by start_process that have recently completed.
        The list contains dicctionary objects with these keys:
            cmd_line [string]: The full command line
            end_time [datetime]: If the process was started using start_process
                    then the process completion time will be available if
                    queried within 5 minutes after it completes. None otherwise
            exit_code [int]: If the process was started using start_process then
                    the process exit code will be available if queried within 5
                    minutes after it completes. None otherwise
            name [string]: The process name
            owner [string]: The process owner
            pid [long]: The process ID
            start_time [datetime] The start time of the process
        """
        if not self._proc_mgr:
            raise VIException("Process operations not supported on this server",
                              FaultTypes.NOT_SUPPORTED)
        if not self._auth_obj:
            raise VIException("You must call first login_in_guest",
                              FaultTypes.INVALID_OPERATION)
        try:
            request = VI.ListProcessesInGuestRequestMsg()
            _this = request.new__this(self._proc_mgr)
            _this.set_attribute_type(self._proc_mgr.get_attribute_type())
            request.set_element__this(_this)
            vm = request.new_vm(self._mor)
            vm.set_attribute_type(self._mor.get_attribute_type())
            request.set_element_vm(vm)
            request.set_element_auth(self._auth_obj)
            pinfo = self._server._proxy.ListProcessesInGuest(request)._returnval
            ret = []
            for proc in pinfo:
                ret.append({
                            'cmd_line':proc.CmdLine,
                            'end_time':getattr(proc, "EndTime", None),
                            'exit_code':getattr(proc, "ExitCode", None),
                            'name':proc.Name,
                            'owner':proc.Owner,
                            'pid':proc.Pid,
                            'start_time':proc.StartTime,
                           })
            return ret
        except (VI.ZSI.FaultException), e:
            raise VIApiException(e)

    def get_environment_variables(self):
        """
        Reads the environment variables from the guest OS (system user). Returns
        a dictionary where keys are the var names and the dict value is the var
        value.
        """
        if not self._proc_mgr:
            raise VIException("Process operations not supported on this server",
                              FaultTypes.NOT_SUPPORTED)
        if not self._auth_obj:
            raise VIException("You must call first login_in_guest",
                              FaultTypes.INVALID_OPERATION)
        try:
            request = VI.ReadEnvironmentVariableInGuestRequestMsg()
            _this = request.new__this(self._proc_mgr)
            _this.set_attribute_type(self._proc_mgr.get_attribute_type())
            request.set_element__this(_this)
            vm = request.new_vm(self._mor)
            vm.set_attribute_type(self._mor.get_attribute_type())
            request.set_element_vm(vm)
            request.set_element_auth(self._auth_obj)
            envvars = self._server._proxy.ReadEnvironmentVariableInGuest(request
                                                                    )._returnval
            return dict([v.split("=", 1) for v in envvars])
        except (VI.ZSI.FaultException), e:
            raise VIApiException(e)

    def start_process(self, program_path, args=None, env=None, cwd=None):
        """
        Starts a program in the guest operating system. Returns the process PID.
            program_path [string]: The absolute path to the program to start.
            args [list of strings]: The arguments to the program.
            env [dictionary]: environment variables to be set for the program
                              being run. Eg. {'foo':'bar', 'varB':'B Value'}
            cwd [string]: The absolute path of the working directory for the
                          program to be run. VMware recommends explicitly
                          setting the working directory for the program to be
                          run. If this value is unset or is an empty string,
                          the behavior depends on the guest operating system.
                          For Linux guest operating systems, if this value is
                          unset or is an empty string, the working directory
                          will be the home directory of the user associated with
                          the guest authentication. For other guest operating
                          systems, if this value is unset, the behavior is
                          unspecified.
        """
        if not self._proc_mgr:
            raise VIException("Process operations not supported on this server",
                              FaultTypes.NOT_SUPPORTED)
        if not self._auth_obj:
            raise VIException("You must call first login_in_guest",
                              FaultTypes.INVALID_OPERATION)
        try:
            request = VI.StartProgramInGuestRequestMsg()
            _this = request.new__this(self._proc_mgr)
            _this.set_attribute_type(self._proc_mgr.get_attribute_type())
            request.set_element__this(_this)
            vm = request.new_vm(self._mor)
            vm.set_attribute_type(self._mor.get_attribute_type())
            request.set_element_vm(vm)
            request.set_element_auth(self._auth_obj)
            spec = request.new_spec()
            spec.set_element_programPath(program_path)
            if env: spec.set_element_envVariables(["%s=%s" % (k,v)
                                                  for k,v in env.iteritems()])
            if cwd: spec.set_element_workingDirectory(cwd)
            spec.set_element_arguments("")
            if args:
                import subprocess
                spec.set_element_arguments(subprocess.list2cmdline(args))

            request.set_element_spec(spec)

            return self._server._proxy.StartProgramInGuest(request)._returnval
        except (VI.ZSI.FaultException), e:
            raise VIApiException(e)

    def terminate_process(self, pid):
        """
        Terminates a process in the guest OS..
            pid [long]: The process identifier
        """
        if not self._proc_mgr:
            raise VIException("Process operations not supported on this server",
                              FaultTypes.NOT_SUPPORTED)
        if not self._auth_obj:
            raise VIException("You must call first login_in_guest",
                              FaultTypes.INVALID_OPERATION)
        try:
            request = VI.TerminateProcessInGuestRequestMsg()
            _this = request.new__this(self._proc_mgr)
            _this.set_attribute_type(self._proc_mgr.get_attribute_type())
            request.set_element__this(_this)
            vm = request.new_vm(self._mor)
            vm.set_attribute_type(self._mor.get_attribute_type())
            request.set_element_vm(vm)
            request.set_element_auth(self._auth_obj)
            request.set_element_pid(pid)
            self._server._proxy.TerminateProcessInGuest(request)
        except (VI.ZSI.FaultException), e:
            raise VIApiException(e)

    #-------------------#
    #-- OTHER METHODS --#
    #-------------------#

    def get_property(self, name='', from_cache=True):
        """"Returns the VM property with the given @name or None if the property
        doesn't exist or have not been set. The property is looked in the cached
        info obtained from the last time the server was requested.
        If you expect to get a volatile property (that might have changed since
        the last time the properties were queried), you may set @from_cache to
        True to refresh all the properties.
        The properties you may get are:
            name: Name of this entity, unique relative to its parent.
            path: Path name to the configuration file for the virtual machine
                  e.g., the .vmx file.
            guest_id:
            guest_full_name:
            hostname:
            ip_address:
            mac_address
            net: [{connected, mac_address, ip_addresses, network},...]
        """
        if not from_cache:
            self.__update_properties()
        return self._properties.get(name)

    def get_properties(self, from_cache=True):
        """Returns a dictionary of property of this VM.
        If you expect to get a volatile property (that might have changed since
        the last time the properties were queried), you may set @from_cache to
        True to refresh all the properties before retrieve them."""
        if not from_cache:
            self.__update_properties()
        return self._properties.copy()


    def get_resource_pool_name(self):
        """Returns the name of the resource pool where this VM belongs to. Or
        None if there isn't any or it can't be retrieved"""
        if self._resource_pool:
            oc = self._server._get_object_properties(
                                   self._resource_pool, property_names=['name'])
            if not hasattr(oc, 'PropSet'):
                return None
            prop_set = oc.PropSet
            if len(prop_set) == 0:
                return None
            for prop in prop_set:
                if prop.Name == 'name':
                    return prop.Val


    def set_extra_config(self, settings, sync_run=True):
        """Sets the advanced configuration settings (as the ones on the .vmx
        file).
          * settings: a key-value pair dictionary with the settings to
            set/change
          * sync_run: if True (default) waits for the task to finish and returns
            (raises an exception if the task didn't succeed). If False the task
            is started and a VITask instance is returned
          * updated to set annotation note on VM
        E.g.:
            #prevent virtual disk shrinking
            vm.set_extra_config({'isolation.tools.diskWiper.disable':'TRUE',
                                 'isolation.tools.diskShrink.disable':'TRUE'})
        """
        try:
            request = VI.ReconfigVM_TaskRequestMsg()
            _this = request.new__this(self._mor)
            _this.set_attribute_type(self._mor.get_attribute_type())
            request.set_element__this(_this)

            spec = request.new_spec()
            extra_config = []
	    if 'notes' in settings:
                spec.set_element_annotation(settings['notes'])
            for k,v in settings.iteritems():
                ec = spec.new_extraConfig()
                ec.set_element_key(str(k))
                ec.set_element_value(str(v))
                extra_config.append(ec)
            spec.set_element_extraConfig(extra_config)

            request.set_element_spec(spec)
            task = self._server._proxy.ReconfigVM_Task(request)._returnval
            vi_task = VITask(task, self._server)
            if sync_run:
                status = vi_task.wait_for_state([vi_task.STATE_SUCCESS,
                                                 vi_task.STATE_ERROR])
                if status == vi_task.STATE_ERROR:
                    raise VIException(vi_task.get_error_message(),
                                      FaultTypes.TASK_ERROR)
                return
            return vi_task
        except (VI.ZSI.FaultException), e:
            raise VIApiException(e)

    #---------------------#
    #-- PRIVATE METHODS --#
    #---------------------#

    def __create_snapshot_list(self):
        """Creates a VISnapshot list with the snapshots this VM has. Stores that
        list in self._snapshot_list"""

        def create_list(snap_list=[], cur_node=None):
            #first create the trees of snapshots
            if not cur_node:
                children = self._root_snapshots
            else:
                children = cur_node.get_children()

            for snap in children:
                    snap_list.append(snap)
                    create_list(snap_list, snap)

            return snap_list

        self._snapshot_list = create_list()

        path_list = []
        for snap in self._snapshot_list:
            path_list.append(snap.get_path())

        path_list = list(set([x for x in path_list if path_list.count(x) > 1]))

        for snap_path in path_list:
            v = 0
            for snap in self._snapshot_list:
                if(snap.get_path() == snap_path):
                    snap._index = v
                    v += 1

    def __create_pendant_task_collector(self):
        """sets the MOR of a TaskHistoryCollector which will retrieve
        the lasts task info related to this VM (or any suboject as snapshots)
        for those task in 'running' or 'queued' states"""
        try:
            mor_task_manager = self._server._do_service_content.TaskManager

            request = VI.CreateCollectorForTasksRequestMsg()
            mor_tm = request.new__this(mor_task_manager)
            mor_tm.set_attribute_type(mor_task_manager.get_attribute_type())
            request.set_element__this(mor_tm)

            do_task_filter_spec = request.new_filter()
            do_task_filter_spec.set_element_state(['running', 'queued'])

            do_tfs_by_entity = do_task_filter_spec.new_entity()
            mor_entity = do_tfs_by_entity.new_entity(self._mor)
            mor_entity.set_attribute_type(self._mor.get_attribute_type())
            do_tfs_by_entity.set_element_entity(mor_entity)
            do_tfs_by_entity.set_element_recursion('all')

            do_task_filter_spec.set_element_entity(do_tfs_by_entity)

            request.set_element_filter(do_task_filter_spec)
            ret = self._server._proxy.CreateCollectorForTasks(request) \
                                                                     ._returnval
            self._mor_vm_task_collector = ret

        except (VI.ZSI.FaultException), e:
            raise VIApiException(e)

    def __delete_snapshot(self, mor, remove_children, sync_run):
        """Deletes the snapshot of the given MOR. If remove_children is True,
        deletes all the snapshots in the subtree as well. If @sync_run is True
        (default) waits for the task to finish, and returns
        (raises an exception if the task didn't succeed). If sync_run is set to
        False the task is started an a VITask instance is returned."""
        try:
            request = VI.RemoveSnapshot_TaskRequestMsg()
            mor_snap = request.new__this(mor)
            mor_snap.set_attribute_type(mor.get_attribute_type())
            request.set_element__this(mor_snap)
            request.set_element_removeChildren(remove_children)

            task = self._server._proxy.RemoveSnapshot_Task(request)._returnval
            vi_task = VITask(task, self._server)
            if sync_run:
                status = vi_task.wait_for_state([vi_task.STATE_SUCCESS,
                                                 vi_task.STATE_ERROR])
                self.refresh_snapshot_list()
                if status == vi_task.STATE_ERROR:
                    raise VIException(vi_task.get_error_message(),
                                      FaultTypes.TASK_ERROR)
                return

            return vi_task

        except (VI.ZSI.FaultException), e:
            raise VIApiException(e)

    def __validate_authentication(self, auth_obj):
        if not self._auth_mgr:
            raise VIException("Guest Operations only available since API 5.0",
                              FaultTypes.NOT_SUPPORTED)
        try:
            request = VI.ValidateCredentialsInGuestRequestMsg()
            _this = request.new__this(self._auth_mgr)
            _this.set_attribute_type(self._auth_mgr.get_attribute_type())
            request.set_element__this(_this)
            vm = request.new_vm(self._mor)
            vm.set_attribute_type(self._mor.get_attribute_type())
            request.set_element_vm(vm)
            request.set_element_auth(auth_obj)
            self._server._proxy.ValidateCredentialsInGuest(request)
        except (VI.ZSI.FaultException), e:
            raise VIApiException(e)

    def __update_properties(self):
        """Refreshes the properties retrieved from the virtual machine
        (i.e. name, path, snapshot tree, etc). To reduce traffic, all the
        properties are retrieved from one shot, if you expect changes, then you
        should call this method before other"""

        def update_devices(devices):
            for dev in devices:
                d = {
                     'key': dev.key,
                     'type': dev._type,
                     'unitNumber': getattr(dev,'unitNumber',None),
                     'label': getattr(getattr(dev,'deviceInfo',None),
                                      'label',None),
                     'summary': getattr(getattr(dev,'deviceInfo',None),
                                        'summary',None),
                     '_obj': dev
                     }
                # Network Device
                if hasattr(dev,'macAddress'):
                    d['macAddress'] = dev.macAddress
                    d['addressType'] = getattr(dev,'addressType',None)
                # Video Card
                if hasattr(dev,'videoRamSizeInKB'):
                    d['videoRamSizeInKB'] = dev.videoRamSizeInKB
                # Disk
                if hasattr(dev,'capacityInKB'):
                    d['capacityInKB'] = dev.capacityInKB
                # Controller
                if hasattr(dev,'busNumber'):
                    d['busNumber'] = dev.busNumber
                    d['devices'] = getattr(dev,'device',[])

                self._devices[dev.key] = d

        def update_disks(disks):
            for disk in disks:
                files = []
                committed = 0
                store = None
                for c in getattr(disk, "chain", []):
                    for k in c.fileKey:
                        f = self._files[k]
                        files.append(f)
                        if f['type'] == 'diskExtent':
                            committed += f['size']
                        if f['type'] == 'diskDescriptor':
                            store = f['name']
                dev = self._devices[disk.key]

                self._disks.append({
                                   'device': dev,
                                   'files': files,
                                   'capacity': dev['capacityInKB'],
                                   'committed': committed/1024,
                                   'descriptor': store,
                                   'label': dev['label'],
                                   })

        def update_files(files):
            for file_info in files:
                self._files[file_info.key] = {
                                        'key': file_info.key,
                                        'name': file_info.name,
                                        'size': file_info.size,
                                        'type': file_info.type
                                        }


        try:
            self.properties = VIProperty(self._server, self._mor)
        except (VI.ZSI.FaultException), e:
            raise VIApiException(e)

        p = {}
        p['name'] = self.properties.name

        #------------------------#
        #-- UPDATE CONFIG INFO --#
        if hasattr(self.properties, "config"):
            p['guest_id'] = self.properties.config.guestId
            p['guest_full_name'] = self.properties.config.guestFullName
            if hasattr(self.properties.config.files, "vmPathName"):
                p['path'] = self.properties.config.files.vmPathName
            p['memory_mb'] = self.properties.config.hardware.memoryMB
            p['num_cpu'] = self.properties.config.hardware.numCPU

            if hasattr(self.properties.config.hardware, "device"):
                update_devices(self.properties.config.hardware.device)
                p['devices'] = self._devices

        #-----------------------#
        #-- UPDATE GUEST INFO --#

        if hasattr(self.properties, "guest"):
            if hasattr(self.properties.guest, "hostName"):
                p['hostname'] = self.properties.guest.hostName
            if hasattr(self.properties.guest, "ipAddress"):
                p['ip_address'] = self.properties.guest.ipAddress
            nics = []
            if hasattr(self.properties.guest, "net"):
                for nic in self.properties.guest.net:
                    nics.append({
                                 'connected':getattr(nic, "connected", None),
                                 'mac_address':getattr(nic, "macAddress", None),
                                 'ip_addresses':getattr(nic, "ipAddress", []),
                                 'network':getattr(nic, "network", None)
                                })

                p['net'] = nics

        #------------------------#
        #-- UPDATE LAYOUT INFO --#

        if hasattr(self.properties, "layoutEx"):
            if hasattr(self.properties.layoutEx, "file"):
                update_files(self.properties.layoutEx.file)
                p['files'] = self._files
            if hasattr(self.properties.layoutEx, "disk"):
                update_disks(self.properties.layoutEx.disk)
                p['disks'] = self._disks

        self._properties = p

        #----------------------#
        #-- UPDATE SNAPSHOTS --#

        if hasattr(self.properties, "snapshot"):
            if hasattr(self.properties.snapshot, "currentSnapshot"):
                self.__current_snapshot = \
                                   self.properties.snapshot.currentSnapshot._obj

            self._root_snapshots = []
            for root_snap in self.properties.snapshot.rootSnapshotList:
                root = VISnapshot(root_snap)
                self._root_snapshots.append(root)
            self.__create_snapshot_list()

        #-----------------------#
        #-- SET RESOURCE POOL --#
        if hasattr(self.properties, "resourcePool"):
            self._resource_pool = self.properties.resourcePool._obj


class VMPowerState:
    POWERED_ON              = 'POWERED ON'
    POWERED_OFF             = 'POWERED OFF'
    SUSPENDED               = 'SUSPENDED'
    POWERING_ON             = 'POWERING ON'
    POWERING_OFF            = 'POWERING OFF'
    SUSPENDING              = 'SUSPENDING'
    RESETTING               = 'RESETTING'
    BLOCKED_ON_MSG          = 'BLOCKED ON MSG'
    REVERTING_TO_SNAPSHOT   = 'REVERTING TO SNAPSHOT'
    UNKNOWN                 = 'UNKNOWN'

class ToolsStatus:
    #VMware Tools has never been installed or has not run in the virtual machine
    NOT_INSTALLED   = 'NOT INSTALLED'

    #VMware Tools is not running.
    NOT_RUNNING     = 'NOT RUNNING'

    #VMware Tools is running and the version is current.
    RUNNING         = 'RUNNING'

    #VMware Tools is running, but the version is not current.
    RUNNING_OLD     = 'RUNNING OLD'

    #Couldn't obtain the status of the VMwareTools.
    UNKNOWN         = 'UNKNOWN'
