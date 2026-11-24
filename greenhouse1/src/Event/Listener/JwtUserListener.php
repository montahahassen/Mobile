<?php
namespace App\Event\Listener;
use Lexik\Bundle\JwtAuthenticationBundle\Event\AuthenticationSuccessEvent;
class JwtUserListener{
    public function onAuthenticationSuccess (AuthenticationSuccessEvent $event){
        $data= $event->getData();
        $user= $event->getUser();
        $payload= $data;
        $payload['id']= $user->getId();
        $payload['firstname']= $user->getFirstName();
        $payload['lastname']= $user->getLastName();
        $payload['email']= $user->getEmail();
        $event->setData($payload);

    }
}