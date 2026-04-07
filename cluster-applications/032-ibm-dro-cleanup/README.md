IBM DRO Cleanup
===============================================================================
Contains a PostDelete hook that issues deletes for MarketplaceConfig CRs to allow ibm-dro application uninstall to proceed.
This chart must be managed by an Application in a later syncwave than ibm-dro to ensure the PostDelete hook can
complete before the ibm dro application is removed (otherwise the pods responsible for managing the MarketplaceConfig
finalizers will be removed before they get a chance to complete).