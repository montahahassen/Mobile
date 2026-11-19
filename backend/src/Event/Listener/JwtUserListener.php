<?php

namespace App\Event\Listener;

use App\Entity\User;
use Lexik\Bundle\JWTAuthenticationBundle\Event\AuthenticationSuccessEvent;
use Symfony\Component\Security\Core\Exception\LogicException;

class JwtUserListener
{
    public function onAuthenticationSuccess(AuthenticationSuccessEvent $event): void
    {
        $user = $event->getUser();

        if (!$user instanceof User) {
            throw new LogicException('The JWT authentication listener expects an App\Entity\User.');
        }

        $data = $event->getData();
        $data['id'] = $user->getId();
        $data['firstname'] = $user->getFirstName();
        $data['lastname'] = $user->getLastName();
        $data['email'] = $user->getEmail();

        $event->setData($data);
        
    }

}