import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'scripts'))
from testflight_owner import owner_only, check_group
from app_store_connect import WorkflowError

class RecipientSafety(unittest.TestCase):
    def test_only_account_holder(self):
        owner={'attributes':{'roles':['ACCOUNT_HOLDER'],'username':'owner@example.com'}}
        self.assertEqual(owner_only([owner])['username'],'owner@example.com')
        for users in ([],[owner,owner],[{'attributes':{'roles':['ADMIN']}}]):
            with self.assertRaises(WorkflowError): owner_only(users)
    def test_private_manual_internal_only(self):
        good={'isInternalGroup':True,'publicLinkEnabled':False,'hasAccessToAllBuilds':False}
        check_group({'attributes':good},[{'attributes':{'email':'OWNER@example.com'}}],'owner@example.com')
        for key,value in [('isInternalGroup',False),('publicLinkEnabled',True),('hasAccessToAllBuilds',True)]:
            with self.assertRaises(WorkflowError):
                check_group({'attributes':{**good,key:value}},[],'owner@example.com')
        with self.assertRaises(WorkflowError):
            check_group({'attributes':good},[{'attributes':{'email':'other@example.com'}}],'owner@example.com')

if __name__=='__main__': unittest.main()
