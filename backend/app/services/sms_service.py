"""SMS gateway abstraction so alert triggers don't care which provider is active.

Required per the problem statement: NER connectivity is patchy, so alerts must
reach citizens via SMS in addition to push notifications. Configure the active
provider via SMS_PROVIDER in .env (twilio | msg91).
"""

from abc import ABC, abstractmethod

from app.core.config import get_settings


class SMSGateway(ABC):
    @abstractmethod
    def send(self, to_number: str, message: str) -> bool:
        raise NotImplementedError


class TwilioGateway(SMSGateway):
    def __init__(self):
        settings = get_settings()
        self._account_sid = settings.twilio_account_sid
        self._auth_token = settings.twilio_auth_token
        self._from_number = settings.twilio_from_number

    def send(self, to_number: str, message: str) -> bool:
        # TODO: from twilio.rest import Client; Client(sid, token).messages.create(...)
        raise NotImplementedError("Twilio integration pending credentials")


class MSG91Gateway(SMSGateway):
    def __init__(self):
        settings = get_settings()
        self._auth_key = settings.msg91_auth_key
        self._sender_id = settings.msg91_sender_id
        self._template_id = settings.msg91_template_id

    def send(self, to_number: str, message: str) -> bool:
        # TODO: POST to https://api.msg91.com/api/v5/flow/ with template + auth key
        raise NotImplementedError("MSG91 integration pending credentials")


def get_sms_gateway() -> SMSGateway:
    settings = get_settings()
    if settings.sms_provider == "msg91":
        return MSG91Gateway()
    return TwilioGateway()
