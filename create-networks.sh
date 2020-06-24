#!/bin/sh -e                                                                    
                                                                                
virsh net-destroy default                                                       
virsh net-undefine default                                                      
                                                                                
virsh net-define net-external.xml                                               
virsh net-start external                                                        
virsh net-autostart external                                                    
                                                                                
virsh net-define net-internal.xml                                               
virsh net-start internal                                                        
virsh net-autostart internal
